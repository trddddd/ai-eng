require "net/http"

class AudioController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :require_login

  TATOEBA_AUDIO_BASE = "https://audio.tatoeba.org/sentences/eng".freeze

  def sentence
    audio_id = params[:id].to_i
    uri = URI("#{TATOEBA_AUDIO_BASE}/#{audio_id}.mp3")

    http_response = Net::HTTP.get_response(uri)

    if http_response.is_a?(Net::HTTPSuccess)
      send_data http_response.body,
                type: "audio/mpeg",
                disposition: "inline",
                filename: "#{audio_id}.mp3"
    else
      head :not_found
    end
  end
end
