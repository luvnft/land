# frozen_string_literal: true

class CheckoutController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[success cancel]

  def checkout
    @block = Block.find_by_hashid!(params[:block])
    create_stripe_checkout

    redirect_to @stripe_checkout.url,
                status: :see_other,
                allow_other_host: true
  end

  def success
    render plain: 'Thanks for your order!'
  end

  def cancel
    render plain: 'Forgot to add something to your cart? Shop around then come back to pay!'
  end

  private

  def create_stripe_checkout
    @stripe_checkout = Stripe::Checkout::Session.create({
                                                          customer_email: current_user.email,
                                                          line_items: [{
                                                            # Provide the exact Price ID (e.g. pr_1234) of the product you want to sell
                                                            price: ENV.fetch('STRIPE_PRICE_ID_BLOCK'),
                                                            quantity: 1
                                                          }],
                                                          payment_intent_data: {
                                                            metadata: {
                                                              user: current_user.hashid,
                                                              blocks: @block.hashid
                                                            }
                                                          },
                                                          mode: 'payment',
                                                          success_url: checkout_success_url,
                                                          cancel_url: checkout_cancel_url
                                                        })
  end
end
