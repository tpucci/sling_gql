{{flutter_js}}
{{flutter_build_config}}

// Two ways to start the same build:
// - on its own page (/sling_gql/demo/, or an iframe): the full app, or one
//   demo with ?demo=<name>, in the page's implicit view;
// - inside a docs page that installed `window.slingDemoHost`
//   (website/src/components/LiveApp.astro): one engine with multi-view on,
//   and the page adds a view per demo.
if (window.slingDemoHost) {
  window.slingDemoHost.start(_flutter.loader);
} else {
  _flutter.loader.load();
}
