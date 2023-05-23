class RegistriesController < ApplicationController
  def index
    @registries = Registry.all
  end

  def show
    @registry = Registry.find_by_name!(params[:id])
    @packages = @registry.packages.with_production.order('production DESC')
  end
end