defmodule Loomex.Telemetry do
  require Logger
  
	def init do
	  events = [
		  [:loomex, :listener, :starting],
	    [:loomex, :listener, :started],
			[:loomex, :listener, :stopped],
			[:loomex, :listener, :error]
		]
    :telemetry.attach_many "loomex_telemetry", events, &handle_event/4, nil
	end
	
	def handle_event([:loomex, :listener, :starting], _measurements, _metadata, _config) do
    Logger.info "Listener starting"
	end
	
	def handle_event([:loomex, :listener, :started], _measurements, _metadata, _config) do
	  Logger.info "Listener started"
	end
	
	def handle_event([:loomex, :listener, :stopped], _measurements, _metadata, _config) do
	  Logger.info "Listener stopped"
	end
	
	def handle_event([:loomex, :listener, :error], _measurements, _metadata, _config) do
	  Logger.error "Listener error"
	end
	
	def handle_event(event, _measurements, _metadata, _config) do
    Logger.warning "Undefined event captured: #{inspect event}"
	end
end