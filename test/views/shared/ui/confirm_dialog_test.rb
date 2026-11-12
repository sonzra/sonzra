require "test_helper"

class SharedUiConfirmDialogTest < ActionView::TestCase
  test "renders confirm dialog with default danger styling and accessibility attributes" do
    render partial: "shared/ui/confirm_dialog", locals: {
      eyebrow: "Confirm action",
      title: "Are you absolutely sure?",
      description: "This cannot be undone.",
      cancel_action: "test#cancel",
      confirm_action: "test#confirm",
      confirm_label: "Delete forever"
    }

    assert_select "dialog.redesign-dialog.redesign-dialog--confirm[aria-modal='true']" do
      assert_select ".redesign-dialog__panel[role='document']" do
        assert_select ".redesign-dialog__heading" do
          assert_select "p.redesign-dialog__eyebrow", text: "Confirm action"
          assert_select "h2.redesign-dialog__title", text: "Are you absolutely sure?"
          assert_select "button.redesign-dialog__close[data-action='test#cancel']"
        end
        assert_select "p.redesign-dialog__desc", text: "This cannot be undone."
        assert_select ".redesign-dialog__actions" do
          assert_select "button.secondary-button[data-action='test#cancel']", text: "Cancel"
          assert_select "button.danger-button[data-action='test#confirm']", text: "Delete forever"
        end
      end
    end
  end

  test "renders primary variant when confirm_variant is :primary" do
    render partial: "shared/ui/confirm_dialog", locals: {
      title: "Save changes?",
      cancel_action: "modal#close",
      confirm_action: "modal#save",
      confirm_label: "Save",
      confirm_variant: :primary
    }

    assert_select "dialog.redesign-dialog" do
      assert_select "button.primary-button[data-action='modal#save']", text: "Save"
      assert_select "button.danger-button", 0
    end
  end

  test "merges custom dialog classes, title_id, and data attributes" do
    render partial: "shared/ui/confirm_dialog", locals: {
      dialog_id: "custom-modal",
      dialog_class: "my-custom-dialog-class",
      data: { controller: "custom", player_target: "clearDialog" },
      title_id: "my-title-id",
      title: "Custom Title",
      cancel_action: "custom#cancel",
      confirm_action: "custom#confirm"
    }

    assert_select "dialog#custom-modal.redesign-dialog.my-custom-dialog-class[aria-labelledby='my-title-id']"
    assert_select "dialog[data-controller='custom'][data-player-target='clearDialog']"
    assert_select "h2#my-title-id.redesign-dialog__title", text: "Custom Title"
  end

  test "renders custom dialog_content when provided" do
    render partial: "shared/ui/confirm_dialog", locals: {
      title: "Warning",
      cancel_action: "m#cancel",
      confirm_action: "m#ok",
      dialog_content: '<div class="custom-warning-body">Important notice</div>'.html_safe
    }

    assert_select ".redesign-dialog__panel .custom-warning-body", text: "Important notice"
  end
end
