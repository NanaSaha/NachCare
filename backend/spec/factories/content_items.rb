FactoryBot.define do
  factory :content_item do
    kind { "article" }
    week_no { 1 }
    status { "draft" }
    language_variants { { "en" => { "title" => "Week 1", "body" => "[PLACEHOLDER_CLINICAL] Sample body." } } }
    approvals { [] }
  end
end
