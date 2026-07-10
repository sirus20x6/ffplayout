// memepipe fork: the admin web UI is not used — the stream-stager drives
// ffplayout entirely over its REST API, and :8787 is loopback-only. We
// therefore skip the upstream npm frontend build (which would otherwise
// require Node in the build image and run on every release build). A tiny
// committed stub at frontend/dist/ satisfies the compile-time
// include_dir!("../frontend/dist") in serve/routes.rs.
fn main() {}
