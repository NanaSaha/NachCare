require "rails_helper"

RSpec.describe AuditEvent, type: :model do
  let(:user) { create(:user) }
  let(:patient) { create(:patient) }

  subject(:event) do
    Domain::Audit::Recorder.record!(actor: user, action: "viewed", entity: patient, payload: { note: "demo" })
  end

  describe "R6 append-only enforcement" do
    it "blocks UPDATE at the application layer" do
      expect { event.update!(action: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "blocks DESTROY at the application layer" do
      expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "blocks UPDATE at the database layer even when application callbacks are bypassed" do
      expect { event.update_columns(action: "changed") }
        .to raise_error(ActiveRecord::StatementInvalid, /append-only/)
    end

    it "blocks DELETE at the database layer even when application callbacks are bypassed" do
      expect { event.delete }.to raise_error(ActiveRecord::StatementInvalid, /append-only/)
    end
  end
end
