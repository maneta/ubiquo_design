require 'memcache'

# Base class for widget cache
module UbiquoDesign
  module CacheManagers
    class Memcache < UbiquoDesign::CacheManagers::Base

      CONFIG = Ubiquo::Config.context(:ubiquo_design).get(:memcache)
      DATA_TIMEOUT = CONFIG[:timeout]

      class << self

        protected

        # retrieves the widget content identified by +content_id+
        def retrieve content_id
          connection.get content_id
        end

        # retrieves the widgets content bty han array of +content_ids+
        def multi_retrieve content_ids
          connection.get_multi content_ids 
        end

        # Stores a widget content indexing by a +content_id+
        def store content_id, contents
          connection.set content_id, contents, DATA_TIMEOUT
        end

        # removes the widget content from the store
        def delete content_id
          Rails.logger.debug "Widget cache expiration request for key #{content_id}"
          connection.delete content_id
        end

        # Returns or initializes a memcache connection
        def connection
          @cache = MemCache.new(CONFIG[:server])
        end

      end

    end
  end
end
