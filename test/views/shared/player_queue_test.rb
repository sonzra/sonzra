require "test_helper"

class SharedPlayerQueueTest < ActionView::TestCase
  test "renders clear queue confirmation modal using canonical redesign dialog and button classes" do
    render partial: "shared/player_queue"

    assert_select "dialog.redesign-dialog.redesign-dialog--confirm.listen-queue__confirm[data-player-target='clearDialog']" do
      assert_select ".redesign-dialog__panel.listen-queue__confirm-panel" do
        assert_select ".redesign-dialog__eyebrow", text: "Clear queue"
        assert_select "h2#clear-queue-title.redesign-dialog__title", text: "Stop playback and remove every queued track?"
        assert_select "button.redesign-dialog__close[data-action='player#closeClearQueuePrompt']"
        assert_select "p.redesign-dialog__desc", text: "The current song will stop and the player will be hidden."
        assert_select ".redesign-dialog__actions.listen-queue__confirm-actions" do
          assert_select "button.secondary-button.listen-queue__confirm-cancel[data-action='player#closeClearQueuePrompt']", text: "Cancel"
          assert_select "button.danger-button.listen-queue__confirm-submit[data-action='player#confirmClearQueue']", text: "Clear queue"
        end
      end
    end
  end
end
