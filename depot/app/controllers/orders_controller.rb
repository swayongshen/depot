class OrdersController < ApplicationController
  include CurrentCart
  before_action :authenticate_user!, only: [:index, :show, :update, :ship]
  before_action :set_cart
  before_action :ensure_cart_isnt_empty, only: :new
  before_action :set_order, only: %i[ show edit update destroy ship]

  def filter
    filter_params
    respond_to do |format|
      @orders = Order.includes(line_items: [product: [:user]])
      @orders = @orders.where(line_items: { products: { users: current_user} })
      @orders = @orders.where(email: params[:email]) if params[:email].present?
      @orders = @orders.where(address: params[:address]) if params[:address].present?
      @orders = @orders.where(name: params[:name]) if params[:name].present?

      @orders = @orders.where("orders.created_at >= ?",
                              helpers.parse_user_date_time(params[:from_date])) if params[:from_date].present?
      @orders = @orders.where("orders.created_at <= ?",
                              helpers.parse_user_date_time(params[:to_date])) if params[:to_date].present?
      # If ship_status is not any, filter orders by ship_status
      if params[:ship_status].present? and params[:ship_status] != "Any"
        puts params[:ship_status]
        wanted_orders = @orders.select {|order| !Order.ship_statuses[params[:ship_status]] ^ order.is_user_products_shipped?(current_user)}
        wanted_order_ids = wanted_orders.map {|order| order.id}
        @orders = @orders.where(id: wanted_order_ids)
      end
      if params.empty?
        @orders = Order.none
      end
      if @orders
        @orders = @orders.order("order_id ASC")
      end
      format.html { render :index }
      format.js
    end
  end

  # GET /orders or /orders.json
  def index
    puts filter_orders_url
    puts "INDEX"
    @orders = User.get_all_orders_by_user(current_user)
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
    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to @order, notice: "Order was successfully updated." }
        @orders = User.get_all_orders_by_user(current_user)
        format.js { render 'update', notice: "Order was successfully updated." }
        format.json { render :show, status: :ok, location: @order }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  def ship
    respond_to do |format|
      if @order.mark_user_products_shipped(current_user)
        OrderMailer.shipped(@order, current_user).deliver_later
        format.html { redirect_to @order, notice: "Successfully marked order as shipped." }
        @orders = User.get_all_orders_by_user(current_user)
        format.js { render 'update', notice: "Successfully marked order as shipped." }
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
      format.html { redirect_to orders_url, notice: "Order was successfully deleted." }
      format.json { head :no_content }
    end
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_order
      begin
        @order = Order.where(id: params[:id]).first
        unless is_authorised?(@order)
          unauthorised_access
        end
      rescue ActiveRecord::RecordNotFound
        unauthorised_access
      end
    end

    # Only allow a list of trusted parameters through.
    def order_params
      params.require(:order).permit(:name, :address, :email, :pay_type)
    end

    def ensure_cart_isnt_empty
      if @cart.line_items.empty?
        redirect_to store_index_url, notice: 'Your cart is empty'
      end
    end

    def filter_params
      params.permit(:name, :address, :email, :pay_type, :ship_status, :from_date, :to_date, :commit)
    end


    def invalid_order
      logger.error "Attempted to access invalid order #{params[:id]}"
      redirect_to orders_url, notice: 'Invalid order'
    end

    def unauthorised_access
      flash[:alert] = "You are not authorised to handle order id:#{params[:id]}"
      flash.keep
      redirect_to orders_url
    end

    def is_authorised?(order)
      @order = order
      @order.ordered_line_items_of_user(current_user).size > 0
    end
end
