# Copyright (C) 2014-2020 MongoDB Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongo
  module Auth
    class LDAP

      # Defines behavior around a single PLAIN conversation between the
      # client and server.
      #
      # @since 2.0.0
      class Conversation

        # The login message.
        #
        # @since 2.0.0
        LOGIN = { saslStart: 1, autoAuthorize: 1 }.freeze

        # @return [ Protocol::Message ] reply The current reply in the
        #   conversation.
        attr_reader :reply

        # @return [ User ] user The user for the conversation.
        attr_reader :user

        # Finalize the PLAIN conversation. This is meant to be iterated until
        # the provided reply indicates the conversation is finished.
        #
        # @param [ Protocol::Message ] reply The reply of the previous
        #   message.
        # @param [ Server::Connection ] connection The connection being
        #   authenticated.
        #
        # @return [ Protocol::Query ] The next message to send.
        #
        # @since 2.0.0
        def finalize(reply, connection)
          validate!(reply, connection.server)
        end

        # Start the PLAIN conversation. This returns the first message that
        # needs to be sent to the server.
        #
        # @param [ Server::Connection ] connection The connection being
        #   authenticated.
        #
        # @return [ Protocol::Query ] The first PLAIN conversation message.
        #
        # @since 2.0.0
        def start(connection)
          if connection && connection.features.op_msg_enabled?
            selector = LOGIN.merge(payload: payload, mechanism: LDAP::MECHANISM)
            selector[Protocol::Msg::DATABASE_IDENTIFIER] = Auth::EXTERNAL
            cluster_time = connection.mongos? && connection.cluster_time
            selector[Operation::CLUSTER_TIME] = cluster_time if cluster_time
            Protocol::Msg.new([], {}, selector)
          else
            Protocol::Query.new(
              Auth::EXTERNAL,
              Database::COMMAND,
              LOGIN.merge(payload: payload, mechanism: LDAP::MECHANISM),
              limit: -1
            )
          end
        end

        # Create the new conversation.
        #
        # @example Create the new conversation.
        #   Conversation.new(user, "admin")
        #
        # @param [ Auth::User ] user The user to converse about.
        #
        # @since 2.0.0
        def initialize(user)
          @user = user
        end

        private

        def payload
          BSON::Binary.new("\x00#{user.name}\x00#{user.password}")
        end

        def validate!(reply, server)
          if reply.documents[0][Operation::Result::OK] != 1
            raise Unauthorized.new(user, used_mechanism: MECHANISM, server: server)
          end
          @reply = reply
        end
      end
    end
  end
end
