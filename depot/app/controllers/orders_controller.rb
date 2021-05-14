class OrdersController < ApplicationController
  include CurrentCart
  before_action :authenticate_user!, only: [:index, :show, :update]
  before_action :set_cart, only: [:new, :create]
  before_action :ensure_cart_isnt_empty, only: :new
  before_action :set_order, only: %i[ show edit update destroy ]

  # GET /orders or /orders.json
  def index
    @orders = get_all_orders_by_user
  end

  # GET /orders/1 or /orders/1.json
  def show
    @orders = Order.find_by(id: params[:id])
  end

  # GET /orders/new
  def new
    @order = Order.new
  end

  # GET /orders/1/edit
  def edit
  end

  # POST /orders or /orders.json
  def create
    @order = Order.new(order_params)
    @order.add_line_items_from_cart(@cart)

    respond_to do |format|
      if @order.save
        Cart.destroy(session[:cart_id])
        session[:cart_id] = nil
        OrderMailer.received(@order).deliver_later
        format.html { redirect_to store_index_url, notice:
          'Thank you for your order.' }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /orders/1 or /orders/1.json
  def update
    @orders = get_all_orders_by_user
    respond_to do |format|
      if @order.update(order_params)
        if params[:shipped].present? and params[:shipped]
          OrderMailer.shipped(@order).deliver_later
        end
        format.html { redirect_to @order, notice: "Order was successfully updated." }
        format.js
        format.json { render :show, status: :ok, location: @order }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1 or /orders/1.json
  def destroy
    @order.destroy
    respond_to do |format|
      format.html { redirect_to orders_url, notice: "Order was successfully destroyed." }
      format.json { head :no_content }
    end
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      @order = Order.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def order_params
      params.require(:order).permit(:name, :address, :email, :pay_type, :shipped)
    end

    def ensure_cart_isnt_empty
      if @cart.line_items.empty?
        redirect_to store_index_url, notice: 'Your cart is empty'
      end
    end

    def get_all_orders_by_user
      Order.includes(line_items: [product: [:user]])
                     .where(line_items: { products: { users: current_user} })
    end

    def invalid_order
      logger.error "Attempted to access invalid order #{params[:id]}"
      redirect_to orders_url, notice: 'Invalid order'
    end
end
