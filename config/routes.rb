ActionController::Routing::Routes.draw do |map|
  map.connect 'json_rpc_call.:format', :controller => 'json_rpc_call', :action => 'handle_rpc_request'
end
