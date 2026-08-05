FactoryBot.define do
  factory :knowledge_doc do
    sequence(:title) { |n| "Guide #{n}" }
    language { "en" }
    version { 1 }
    status { "draft" }
    body { "Some approved guidance body text." }
    approvals { [] }
  end
end
