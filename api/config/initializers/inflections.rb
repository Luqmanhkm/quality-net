# frozen_string_literal: true

# Tell Zeitwerk/ActiveSupport how to correctly capitalize "WebSocket" so that
# files like app/channels/audio_websocket_middleware.rb correctly resolve to
# class AudioWebSocketMiddleware (capital S), not AudioWebsocketMiddleware.
#
# Without this, Rails fails to boot entirely whenever eager_load is enabled
# (production, and this app's test/CI environment) — see BUG-008.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "WebSocket"
end