class RegistriesController < ApplicationController
  def index
    @registries = Registry.all.select{|r| r.metadata['packages_count'] > 0}.sort_by{|r| r.metadata['packages_count'] }
  end

  def show
    @registry = Registry.find_by_name!(params[:id])
    @packages = @registry.packages.with_production.order('production DESC')
  end
end