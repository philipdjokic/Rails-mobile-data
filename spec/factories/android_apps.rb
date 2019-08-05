FactoryGirl.define do
  factory :android_app do

    sequence(:app_identifier) { |n| n }

    after(:create) do |android_app, evaluator|
      android_app.newest_android_app_snapshot = FactoryGirl.create(:android_app_snapshot)
    end
  end
end
