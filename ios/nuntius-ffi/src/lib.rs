use std::sync::{Arc, OnceLock};
use tokio::sync::Mutex;

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
    fn on_done(&self, name: String);
    fn on_error(&self, msg: String);
}

// ── SendHandle ────────────────────────────────────────────────────────────────

/// Opaque handle to an active send session.
/// Hold onto this while the receiver is downloading; call stop() when done.
#[derive(uniffi::Object)]
pub struct SendHandle {
    ticket: String,
    router: Mutex<Option<iroh::protocol::Router>>,
    // Keep the collection tag alive so iroh doesn't GC the blobs.
    _tag: iroh_blobs::api::TempTag,
    // Keep the blob store directory alive until the session ends.
    _dir: tempfile::TempDir,
}

#[uniffi::export]
impl SendHandle {
    /// The ticket string the receiver needs to download the file.
    pub fn ticket(&self) -> String {
        self.ticket.clone()
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

/// Start serving a file over iroh P2P.
///
/// Spawns an async task that imports the file, spins up an ephemeral iroh node,
/// and calls callback.on_ready() with the handle. Errors are reported via callback.on_error().
///
/// @param path     Absolute path to the file to send
/// @param callback Receives either the SendHandle or an error message
#[uniffi::export]
pub fn send_file(path: String, callback: Box<dyn SendCallback>) {
    rt().spawn(async move {
        match do_send_file(path).await {
            Ok(handle) => callback.on_ready(handle),
            Err(e) => callback.on_error(e.to_string()),
        }
    });
}

async fn do_send_file(path: String) -> Result<Arc<SendHandle>, NuntiusError> {
    use iroh::{Endpoint, RelayMode, SecretKey};
    use iroh_blobs::{
        api::blobs::{AddPathOptions, AddProgressItem, ImportMode},
        format::collection::Collection,
        store::fs::FsStore,
        ticket::BlobTicket,
        BlobFormat, BlobsProtocol,
    };
    use n0_future::StreamExt;

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
    let blobs = BlobsProtocol::new(&store, None);

    let file_path = std::path::PathBuf::from(&path);
    let name = file_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("file")
        .to_string();

    let mut stream = blobs
        .store()
        .add_path_with_opts(AddPathOptions {
            path: file_path,
            mode: ImportMode::TryReference,
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

    let collection: Collection = [(name, file_tag.hash())].into_iter().collect();
    let collection_tag = collection
        .store(blobs.store())
        .await
        .map_err(|e| e!(e))?;

    drop(file_tag);

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
        _tag: collection_tag,
        _dir: dir,
    }))
}

// ── receive_file ──────────────────────────────────────────────────────────────

/// Download a file using an iroh ticket.
///
/// Spawns an async task that connects to the sender, downloads all blobs, exports
/// the file(s) into dest_dir, and calls callback.on_done() with the filename.
///
/// @param ticket    The ticket string produced by the sender
/// @param dest_dir  Absolute path to the directory where the file will be saved
/// @param callback  Receives either the filename or an error message
#[uniffi::export]
pub fn receive_file(ticket: String, dest_dir: String, callback: Box<dyn ReceiveCallback>) {
    rt().spawn(async move {
        match do_receive_file(ticket, dest_dir).await {
            Ok(name) => callback.on_done(name),
            Err(e) => callback.on_error(e.to_string()),
        }
    });
}

async fn do_receive_file(ticket: String, dest_dir: String) -> Result<String, NuntiusError> {
    use iroh::{Endpoint, RelayMode, SecretKey};
    use iroh_blobs::{
        api::{
            blobs::{ExportMode, ExportOptions, ExportProgressItem},
            remote::GetProgressItem,
        },
        format::collection::Collection,
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

    let local = db
        .remote()
        .local(hash_and_format)
        .await
        .map_err(|e| e!(e))?;

    if !local.is_complete() {
        let mut stream = db
            .remote()
            .execute_get(connection, local.missing())
            .stream();

        while let Some(item) = stream.next().await {
            match item {
                GetProgressItem::Done(_) => break,
                GetProgressItem::Error(cause) => return Err(e!(cause)),
                GetProgressItem::Progress(_) => continue,
            }
        }
    }

    let collection = Collection::load(hash_and_format.hash, db.as_ref())
        .await
        .map_err(|e| e!(e))?;

    let dest = std::path::PathBuf::from(&dest_dir);
    let mut first_name = String::new();

    for (name, hash) in collection.iter() {
        if first_name.is_empty() {
            first_name = name.clone();
        }
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

    if first_name.is_empty() {
        return Err(e!("received collection was empty"));
    }

    Ok(first_name)
}
