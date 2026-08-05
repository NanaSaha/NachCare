require "rails_helper"

RSpec.describe SlaWatchJob do
  let(:episode) { create(:episode) }

  it "marks an open flag breached once its SLA deadline has passed" do
    flag = create(:flag, episode: episode, state: "open", sla_deadline_at: 1.minute.ago, breach: false)

    described_class.new.perform

    expect(flag.reload.breach).to be true
  end

  it "does not touch a flag whose deadline has not passed" do
    flag = create(:flag, episode: episode, state: "open", sla_deadline_at: 1.hour.from_now, breach: false)

    described_class.new.perform

    expect(flag.reload.breach).to be false
  end

  it "does not touch a resolved flag even past its deadline" do
    flag = create(:flag, episode: episode, state: "resolved", sla_deadline_at: 1.minute.ago, breach: false)

    described_class.new.perform

    expect(flag.reload.breach).to be false
  end

  it "does not error on a flag with no SLA deadline (e.g. green — never happens today, but defensive)" do
    create(:flag, episode: episode, state: "open", sla_deadline_at: nil, breach: false)

    expect { described_class.new.perform }.not_to raise_error
  end

  it "is idempotent — running twice does not error or change already-breached flags" do
    flag = create(:flag, episode: episode, state: "open", sla_deadline_at: 1.minute.ago, breach: false)

    described_class.new.perform
    described_class.new.perform

    expect(flag.reload.breach).to be true
  end
end
