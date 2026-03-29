use std::sync::{Arc, OnceLock};
use tokio::sync::{Mutex, mpsc};

uniffi::setup_scaffolding!();

static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

fn rt() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .unwrap()
    })
}

// ── Error ─────────────────────────────────────────────────────────────────────

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum NuntiusError {
    #[error("{msg}")]
    Error { msg: String },
}

macro_rules! e {
    ($val:expr) => {
        NuntiusError::Error { msg: $val.to_string() }
    };
}

// ── Callbacks ─────────────────────────────────────────────────────────────────

#[uniffi::export(callback_interface)]
pub trait SendCallback: Send + Sync {
    fn on_ready(&self, handle: Arc<SendHandle>);
    fn on_error(&self, msg: String);
}

#[uniffi::export(callback_interface)]
pub trait ReceiveCallback: Send + Sync {
    fn on_progress(&self, bytes_received: u64, total_bytes: u64);
    fn on_done(&self, names: Vec<String>);
    fn on_error(&self, msg: String);
}

/// Progress events for the sender side. Registered on a SendHandle after it is ready.
#[uniffi::export(callback_interface)]
pub trait SendProgressCallback: Send + Sync {
    /// Called when a receiver first connects.
    fn on_receiver_connected(&self);
    /// Called repeatedly as bytes are transferred to the receiver.
    fn on_progress(&self, bytes_sent: u64, total_bytes: u64);
    /// Called when the receiver has finished downloading.
    fn on_done(&self);
}

// ── SendHandle ────────────────────────────────────────────────────────────────

/// Opaque handle to an active send session.
/// Hold onto this while the receiver is downloading; call stop() when done.
#[derive(uniffi::Object)]
pub struct SendHandle {
    ticket: String,
    router: Mutex<Option<iroh::protocol::Router>>,
    event_rx: Mutex<Option<mpsc::Receiver<iroh_blobs::provider::events::ProviderMessage>>>,
    // Keep the collection tag alive so iroh doesn't GC the blobs.
    _tag: iroh_blobs::api::TempTag,
    // Keep the store alive — dropping it shuts down the blob-serving actor.
    _store: iroh_blobs::store::fs::FsStore,
    // Keep the blob store directory alive until the session ends.
    _dir: tempfile::TempDir,
}

#[uniffi::export]
impl SendHandle {
    /// The ticket string the receiver needs to download the file.
    pub fn ticket(&self) -> String {
        self.ticket.clone()
    }

    /// Register a callback that receives connection and transfer progress events.
    /// May only be called once; subsequent calls are no-ops.
    pub fn on_send_progress(&self, callback: Box<dyn SendProgressCallback>) {
        let rx = rt().block_on(async { self.event_rx.lock().await.take() });
        let Some(mut rx) = rx else { return };

        let callback = Arc::new(callback);
        let completed = Arc::new(std::sync::atomic::AtomicBool::new(false));

        rt().spawn(async move {
            use iroh_blobs::provider::events::{ProviderMessage, RequestUpdate};

            while let Some(msg) = rx.recv().await {
                match msg {
                    ProviderMessage::ClientConnectedNotify(_) => {
                        callback.on_receiver_connected();
                    }
                    ProviderMessage::GetRequestReceivedNotify(msg) => {
                        let cb = Arc::clone(&callback);
                        let done_flag = Arc::clone(&completed);
                        let mut request_rx = msg.rx;
                        tokio::spawn(async move {
                            let mut total = 0u64;
                            while let Ok(Some(update)) = request_rx.recv().await {
                                match update {
                                    RequestUpdate::Started(s) => {
                                        total = s.size;
                                    }
                                    RequestUpdate::Progress(p) => {
                                        cb.on_progress(p.end_offset, total);
                                    }
                                    RequestUpdate::Completed(_) => {
                                        done_flag.store(true, std::sync::atomic::Ordering::SeqCst);
                                        break;
                                    }
                                    RequestUpdate::Aborted(_) => break,
                                }
                            }
                        });
                    }
                    ProviderMessage::ConnectionClosed(_) => {
                        if completed.load(std::sync::atomic::Ordering::SeqCst) {
                            callback.on_done();
                        }
                        break;
                    }
                    _ => {}
                }
            }
        });
    }

    /// Shut down the sender. Call this after the transfer completes.
    pub fn stop(&self) {
        rt().block_on(async {
            let mut guard: tokio::sync::MutexGuard<Option<iroh::protocol::Router>> =
                self.router.lock().await;
            if let Some(router) = guard.take() {
                let _ = router.shutdown().await;
            }
        });
    }
}

// ── send_file ─────────────────────────────────────────────────────────────────

/// Start serving one or more files over iroh P2P.
///
/// Spawns an async task that imports all files into a single collection, spins up an
/// ephemeral iroh node, and calls callback.on_ready() with the handle. Errors are
/// reported via callback.on_error().
///
/// @param paths    Absolute paths to the files to send
/// @param callback Receives either the SendHandle or an error message
#[uniffi::export]
pub fn send_files(paths: Vec<String>, callback: Box<dyn SendCallback>) {
    rt().spawn(async move {
        match do_send_files(paths).await {
            Ok(handle) => callback.on_ready(handle),
            Err(e) => callback.on_error(e.to_string()),
        }
    });
}

async fn do_send_files(paths: Vec<String>) -> Result<Arc<SendHandle>, NuntiusError> {
    use iroh::{Endpoint, RelayMode, SecretKey};
    use iroh_blobs::{
        api::blobs::{AddPathOptions, AddProgressItem, ImportMode},
        format::collection::Collection,
        provider::events::{ConnectMode, EventMask, EventSender, RequestMode},
        store::fs::FsStore,
        ticket::BlobTicket,
        BlobFormat, BlobsProtocol,
    };
    use n0_future::StreamExt;

    if paths.is_empty() {
        return Err(e!("no files to send"));
    }

    let secret_key = SecretKey::generate(&mut rand::rng());

    let endpoint = Endpoint::builder(iroh::endpoint::presets::N0)
        .alpns(vec![iroh_blobs::protocol::ALPN.to_vec()])
        .secret_key(secret_key)
        .relay_mode(RelayMode::Default)
        .bind()
        .await
        .map_err(|e| e!(e))?;

    let dir = tempfile::tempdir().map_err(|e| e!(e))?;
    let store = FsStore::load(dir.path()).await.map_err(|e| e!(e))?;

    let (event_tx, event_rx) = mpsc::channel(32);
    let blobs = BlobsProtocol::new(
        &store,
        Some(EventSender::new(
            event_tx,
            EventMask {
                connected: ConnectMode::Notify,
                get: RequestMode::NotifyLog,
                ..EventMask::DEFAULT
            },
        )),
    );

    // Import each file and accumulate (name, hash) entries.
    // Keep TempTags alive until the collection is stored so blobs aren't GC'd.
    let mut file_tags: Vec<iroh_blobs::api::TempTag> = Vec::new();
    let mut entries: Vec<(String, iroh_blobs::Hash)> = Vec::new();

    for path in &paths {
        let file_path = std::path::PathBuf::from(path);
        let name = file_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("file")
            .to_string();

        let mut stream = blobs
            .store()
            .add_path_with_opts(AddPathOptions {
                path: file_path,
                mode: ImportMode::Copy,
                format: BlobFormat::Raw,
            })
            .stream()
            .await;

        let file_tag = loop {
            match stream.next().await {
                Some(AddProgressItem::Done(tag)) => break tag,
                Some(AddProgressItem::Error(cause)) => return Err(e!(cause)),
                Some(_) => continue,
                None => return Err(e!("import stream ended without a result")),
            }
        };

        entries.push((name, file_tag.hash()));
        file_tags.push(file_tag);
    }

    let collection: Collection = entries.into_iter().collect();
    let collection_tag = collection
        .store(blobs.store())
        .await
        .map_err(|e| e!(e))?;

    drop(file_tags);

    let hash = collection_tag.hash();

    let router = iroh::protocol::Router::builder(endpoint)
        .accept(iroh_blobs::ALPN, blobs)
        .spawn();

    let ep = router.endpoint();
    let _ = tokio::time::timeout(std::time::Duration::from_secs(10), ep.online()).await;

    let addr = router.endpoint().addr();
    let ticket = BlobTicket::new(addr, hash, BlobFormat::HashSeq);

    Ok(Arc::new(SendHandle {
        ticket: ticket.to_string(),
        router: Mutex::new(Some(router)),
        event_rx: Mutex::new(Some(event_rx)),
        _tag: collection_tag,
        _store: store,
        _dir: dir,
    }))
}

// ── receive_file ──────────────────────────────────────────────────────────────

/// Download a file using an iroh ticket.
///
/// Spawns an async task that connects to the sender, downloads all blobs, exports
/// the file(s) into dest_dir, and calls callback.on_done() with the filename.
/// Progress is reported via callback.on_progress() during the download.
///
/// @param ticket    The ticket string produced by the sender
/// @param dest_dir  Absolute path to the directory where the file will be saved
/// @param callback  Receives progress updates, the filename on success, or an error message
#[uniffi::export]
pub fn receive_file(ticket: String, dest_dir: String, callback: Box<dyn ReceiveCallback>) {
    let callback = Arc::new(callback);
    rt().spawn(async move {
        match do_receive_file(ticket, dest_dir, Arc::clone(&callback)).await {
            Ok(names) => callback.on_done(names),
            Err(e) => callback.on_error(e.to_string()),
        }
    });
}

async fn do_receive_file(
    ticket: String,
    dest_dir: String,
    callback: Arc<Box<dyn ReceiveCallback>>,
) -> Result<Vec<String>, NuntiusError> {
    use iroh::{Endpoint, RelayMode, SecretKey};
    use iroh_blobs::{
        api::{
            blobs::{ExportMode, ExportOptions, ExportProgressItem},
            remote::GetProgressItem,
        },
        format::collection::Collection,
        get::request::get_hash_seq_and_sizes,
        store::fs::FsStore,
        ticket::BlobTicket,
    };
    use n0_future::StreamExt;
    use std::str::FromStr;

    let ticket = BlobTicket::from_str(&ticket).map_err(|e| e!(e))?;
    let addr = ticket.addr().clone();
    let hash_and_format = ticket.hash_and_format();

    let secret_key = SecretKey::generate(&mut rand::rng());
    let endpoint = Endpoint::builder(iroh::endpoint::presets::N0)
        .alpns(vec![])
        .secret_key(secret_key)
        .relay_mode(RelayMode::Default)
        .bind()
        .await
        .map_err(|e| e!(e))?;

    let dir = tempfile::tempdir().map_err(|e| e!(e))?;
    let db = FsStore::load(dir.path()).await.map_err(|e| e!(e))?;

    let connection = endpoint
        .connect(addr, iroh_blobs::protocol::ALPN)
        .await
        .map_err(|e| e!(e))?;

    // Fetch sizes before downloading so we can report meaningful progress.
    let (_hash_seq, sizes) = get_hash_seq_and_sizes(
        &connection,
        &hash_and_format.hash,
        1024 * 1024 * 32,
        None,
    )
    .await
    .map_err(|e| e!(e))?;
    let total_bytes: u64 = sizes.iter().copied().sum();

    let local = db
        .remote()
        .local(hash_and_format)
        .await
        .map_err(|e| e!(e))?;

    if !local.is_complete() {
        let local_bytes = local.local_bytes();
        let mut stream = db
            .remote()
            .execute_get(connection, local.missing())
            .stream();

        while let Some(item) = stream.next().await {
            match item {
                GetProgressItem::Progress(offset) => {
                    callback.on_progress(local_bytes + offset, total_bytes);
                }
                GetProgressItem::Done(_) => break,
                GetProgressItem::Error(cause) => return Err(e!(cause)),
            }
        }
    }

    let collection = Collection::load(hash_and_format.hash, db.as_ref())
        .await
        .map_err(|e| e!(e))?;

    let dest = std::path::PathBuf::from(&dest_dir);
    let mut names: Vec<String> = Vec::new();

    for (name, hash) in collection.iter() {
        names.push(name.clone());
        let target = dest.join(name);
        if let Some(parent) = target.parent() {
            tokio::fs::create_dir_all(parent)
                .await
                .map_err(|e| e!(e))?;
        }

        let mut stream = db
            .export_with_opts(ExportOptions {
                hash: *hash,
                target,
                mode: ExportMode::Copy,
            })
            .stream()
            .await;

        while let Some(item) = stream.next().await {
            match item {
                ExportProgressItem::Done => break,
                ExportProgressItem::Error(cause) => return Err(e!(cause)),
                ExportProgressItem::Size(_) | ExportProgressItem::CopyProgress(_) => continue,
            }
        }
    }

    endpoint.close().await;
    db.shutdown().await.map_err(|e| e!(e))?;

    if names.is_empty() {
        return Err(e!("received collection was empty"));
    }

    Ok(names)
}
