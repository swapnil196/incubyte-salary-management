# Serves the single page that boots the React application. Every non-API path
# renders this, so client-side routes survive a browser reload.
class AppController < ApplicationController
  def index
    render :index
  end
end
