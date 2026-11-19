require "test_helper"

class LinkPreviewJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class PreviewJob < LinkPreviewJob
    attr_accessor :html

    private

    def fetch_html(url)
      html
    end
  end

  setup do
    user = User.create!(email: "preview@example.com", password: "password123", display_name: "Preview")
    conversation = Conversation.create!(conversation_type: :direct)
    @message = conversation.messages.create!(sender: user, content: "Veja https://example.com/article")
    @job = PreviewJob.new
  end

  test "stores metadata and resolves relative image URLs" do
    @job.html = '<meta property="og:title" content="Example"><meta property="og:image" content="/cover.png">'
    assert_enqueued_with(job: MessageUpdateBroadcastJob, args: [ @message.id ]) do
      @job.perform(@message.id)
    end
    preview = @message.reload.metadata.fetch("link_preview")
    assert_equal "Example", preview["title"]
    assert_equal "https://example.com/cover.png", preview["image_url"]
  end

  test "renders a URL fallback for HTML without metadata" do
    @job.html = "<html><body>Hello</body></html>"
    @job.perform(@message.id)
    assert_equal({ "url" => "https://example.com/article" }, @message.reload.metadata["link_preview"])
  end

  test "failed fetch leaves message unchanged" do
    @job.html = nil
    @job.perform(@message.id)
    assert_nil @message.reload.metadata["link_preview"]
  end
end
