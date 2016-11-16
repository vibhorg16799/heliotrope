FactoryGirl.define do
  factory :file_set do
    transient do
      user { FactoryGirl.create(:user) }
      content nil
    end

    after(:build) do |work, evaluator|
      work.apply_depositor_metadata(evaluator.user.user_key)
    end

    after(:create) do |file, evaluator|
      if evaluator.content
        Hydra::Works::UploadFileToFileSet.call(file, evaluator.content)
      end
    end

    sequence(:title) { |n| ["Test FileSet #{n}"] }
    sequence(:search_year, 1900, &:to_s)
    # pad this one out so that string comparisons are consistent
    sequence(:resource_type) { |n| ["audio#{n.to_s.rjust(4, '0')}"] }
    date_uploaded { CurationConcerns::TimeService.time_in_utc }
    visibility Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE

    factory :public_file_set do
      visibility Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    end
  end
end
