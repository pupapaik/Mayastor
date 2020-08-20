pub mod pool_grpc;

use std::error::Error;

use futures::Future;
use tonic::{Response, Status};

pub use server::MayastorGrpcServer;

use crate::{
    core::{Cores, Reactor},
    subsys::Config,
};

fn print_error_chain(err: &dyn std::error::Error) -> String {
    let mut msg = format!("{}", err);
    let mut opt_source = err.source();
    while let Some(source) = opt_source {
        msg = format!("{}: {}", msg, source);
        opt_source = source.source();
    }
    msg
}

/// Macro locally is used to spawn a future on the same thread that executes
/// the macro. That is needed to guarantee that the execution context does
/// not leave the mgmt core (core0) that is a basic assumption in spdk. Also
/// the input/output parameters don't have to be Send and Sync in that case,
/// which simplifies the code. The value of the macro is Ok() variant of the
/// expression in the macro. Err() variant returns from the function.
#[macro_export]
macro_rules! locally {
    ($body:expr) => {{
        let hdl = crate::core::Reactors::current().spawn_local($body);
        match hdl.await.unwrap() {
            Ok(res) => res,
            Err(err) => {
                error!("{}", crate::grpc::print_error_chain(&err));
                return Err(err.into());
            }
        }
    }};
}

mod bdev_grpc;
mod mayastor_grpc;
mod nexus_grpc;
mod server;

pub type GrpcResult<T> = std::result::Result<Response<T>, Status>;

/// call the given future within the context of the reactor on the first core
/// on the init thread, while the future is waiting to be completed the reactor
/// is continuously polled so that forward progress can be made
pub fn rpc_call<G, I, L, A>(future: G) -> Result<Response<A>, tonic::Status>
where
    G: Future<Output = Result<I, L>> + 'static,
    I: 'static,
    A: 'static + From<I>,
    L: Into<Status> + Error + 'static,
{
    assert_eq!(Cores::current(), Cores::first());
    Reactor::block_on(future)
        .unwrap()
        .map(|r| Response::new(A::from(r)))
        .map_err(|e| e.into())
}

/// Used by the gRPC method implementations to sync the current configuration by
/// exporting it to a config file
/// If `sync_config` fails then the method should return a failure
/// requiring the gRPC caller to retry the method, which should be idempotent
pub async fn sync_config<F, T>(future: F) -> GrpcResult<T>
where
    F: Future<Output = GrpcResult<T>>,
{
    let result = future.await;
    if result.is_ok() {
        if let Err(e) = Config::export_config() {
            error!("Failed to export config file: {}", e);
            return Err(Status::data_loss("Failed to export config"));
        }
    }
    result
}
