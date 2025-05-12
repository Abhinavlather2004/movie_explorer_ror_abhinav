FactoryBot.define do
  factory :subscription do
    plan_type { 'basic' }
    status { 'active' }
    association :user
    stripe_customer_id { 'cus_12345' }
    stripe_subscription_id { 'sub_12345' }
    expires_at { 1.month.from_now }
  end
end