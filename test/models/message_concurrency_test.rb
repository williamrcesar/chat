require "test_helper"

class MessageConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "concurrent sends allocate unique ordered sequences" do
    user = User.create!(email: "concurrency@example.com", password: "password123", display_name: "Concurrent")
    conversation = Conversation.create!(conversation_type: :direct)
    ready = Queue.new
    start = Queue.new
    workers = 4.times.map do
      Thread.new do
        ready << true
        start.pop
        ActiveRecord::Base.connection_pool.with_connection do
          3.times do
            Message.create!(conversation_id: conversation.id, sender_id: user.id, content: "Concurrent message")
          end
        end
      end
    end
    4.times { ready.pop }
    4.times { start << true }
    workers.each(&:value)
    assert_equal (1..12).to_a, conversation.messages.order(:sequence).pluck(:sequence)
  ensure
    workers&.each(&:join)
    conversation&.destroy!
    user&.destroy!
  end
end
