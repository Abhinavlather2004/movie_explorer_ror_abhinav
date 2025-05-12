require 'rails_helper'

RSpec.describe Subscription, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    context 'plan_type validations' do
      it 'is valid with a valid plan_type' do
        subscription = build(:subscription, plan_type: 'basic', user: user)
        expect(subscription).to be_valid
      end

      it 'is invalid with an invalid plan_type' do
        subscription = build(:subscription, plan_type: 'invalid', user: user)
        expect(subscription).not_to be_valid
        expect(subscription.errors[:plan_type]).to include('is not included in the list')
      end
    end

    context 'status validations' do
      it 'is valid with a valid status' do
        subscription = build(:subscription, status: 'active', user: user)
        expect(subscription).to be_valid
      end

      it 'is invalid with an invalid status' do
        subscription = build(:subscription, status: 'unknown', user: user)
        expect(subscription).not_to be_valid
        expect(subscription.errors[:status]).to include('is not included in the list')
      end
    end
  end

  describe 'constants' do
    it 'defines PLAN_TYPES correctly' do
      expect(Subscription::PLAN_TYPES).to eq(%w[basic premium])
    end

    it 'defines STATUSES correctly' do
      expect(Subscription::STATUSES).to eq(%w[active inactive cancelled])
    end
  end

  describe 'instance methods' do
    describe '#basic?' do
      it 'returns true if the plan type is basic' do
        subscription = build(:subscription, plan_type: 'basic', user: user)
        expect(subscription.basic?).to be true
      end

      it 'returns false if the plan type is not basic' do
        subscription = build(:subscription, plan_type: 'premium', user: user)
        expect(subscription.basic?).to be false
      end
    end

    describe '#premium?' do
      it 'returns true if the plan type is premium' do
        subscription = build(:subscription, plan_type: 'premium', user: user)
        expect(subscription.premium?).to be true
      end

      it 'returns false if the plan type is not premium' do
        subscription = build(:subscription, plan_type: 'basic', user: user)
        expect(subscription.premium?).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.ransackable_attributes' do
      it 'returns the correct ransackable attributes' do
        expect(Subscription.ransackable_attributes).to eq(%w[
          id user_id plan_type status created_at updated_at
          stripe_customer_id stripe_subscription_id expires_at
        ])
      end
    end

    describe '.ransackable_associations' do
      it 'returns the correct ransackable associations' do
        expect(Subscription.ransackable_associations).to eq(%w[user])
      end
    end
  end
end
