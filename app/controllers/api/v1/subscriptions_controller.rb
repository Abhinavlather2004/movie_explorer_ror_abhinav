class Api::V1::SubscriptionsController < ApplicationController
  before_action :authenticate_user!, except: [:success]
  skip_before_action :verify_authenticity_token

  def create
    subscription = @current_user.subscription
    plan_type = params[:plan_type]
    return render json: { error: 'Invalid plan type' }, status: :bad_request unless %w[1_day 7_days 1_month].include?(plan_type)
    price_id = case plan_type
               when '1_day'
                 ENV['STRIPE_PRICE_1_DAY']
               when '7_days'
                 ENV['STRIPE_PRICE_7_DAYS']
               when '1_month'
                 ENV['STRIPE_PRICE_1_MONTH']
               end

    session = Stripe::Checkout::Session.create(
      customer: subscription.stripe_customer_id,
      payment_method_types: ['card'],
      line_items: [{ price: price_id, quantity: 1 }],
      mode: 'payment',
      metadata: {
        user_id: @current_user.id,
        plan_type: plan_type
      },
      
      success_url: "#{ENV['SUCCESS_URL']}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{ENV['CANCEL_URL']}"
    )

    render json: { session_id: session.id, url: session.url }, status: :ok
    return
  end
  
  def success
    session = Stripe::Checkout::Session.retrieve(params[:session_id])
    subscription = Subscription.find_by(stripe_customer_id: session.customer)
  
    if subscription
      plan_type = session.metadata.plan_type
      expires_at = case plan_type
        when '1_day'
          1.day.from_now
        when '7_days'
          7.days.from_now
        when '1_month'
          1.month.from_now
        end
      subscription.update(stripe_subscription_id: session.subscription, plan_type: 'premium', status: 'active', expires_at: expires_at)
      render json: { message: 'Subscription updated successfully' }, status: :ok
    else
      render json: { error: 'Subscription not found' }, status: :not_found
    end
  end

  def cancel
    render json: { message: 'Payment cancelled' }, status: :ok
  end

  def status
    subscription = @current_user.subscription

    if subscription.nil?
      render json: { error: 'No active subscription found' }, status: :not_found
      return
    end

    if subscription.plan_type == 'premium' && subscription.expires_at.present? && subscription.expires_at < Time.current
      subscription.update(plan_type: 'basic', status: 'active', expires_at: nil)
      render json: { plan_type: 'basic', message: 'Your subscription has expired. Downgrading to basic plan.' }, status: :ok
    else
      render json: { plan_type: subscription.plan_type }, status: :ok
    end
  end

  def index
    subscription = @current_user.subscription
    render json: { subscription: subscription }, status: :ok
  end

  def show
    render json: { subscription: @subscription }, status: :ok
  end
end