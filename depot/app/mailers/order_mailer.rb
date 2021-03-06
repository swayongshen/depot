class OrderMailer < ApplicationMailer
  default from: 'Swa Yong Shen <yongshen.swa@wright.com.sg>'
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.order_mailer.received.subject
  #
  def received(order)
    @order = order
    mail to: order.email, subject: "Pragmatic Store Order Confirmation"
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.order_mailer.shipped.subject
  #
  def shipped(order, seller)
    @seller = seller
    @order = order
    mail to: order.email, subject: "Pragmatic Store Order Shipped"
  end
end
