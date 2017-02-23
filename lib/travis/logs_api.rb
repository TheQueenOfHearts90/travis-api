require 'json'
require 'faraday'

require 'travis/model/remote_log'

module Travis
  class LogsApi
    def initialize(url: '', auth_token: '')
      @url = url
      @auth_header = "token #{auth_token}"
    end

    attr_reader :url, :auth_header
    private :url
    private :auth_header

    def find_by_id(log_id)
      find_by('id', log_id)
    end

    def find_by_job_id(job_id)
      find_by('job_id', job_id)
    end

    private def find_by(by, id)
      resp = conn.get do |req|
        req.url "/logs/#{id}", by: by
        req.headers['Authorization'] = auth_header
      end
      return nil unless resp.success?
      RemoteLog.new(JSON.parse(resp.body))
    end

    private def conn
      @conn ||= Faraday.new(url: url)
    end
  end
end