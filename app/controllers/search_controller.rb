# coding: utf-8
class SearchController < ApplicationController
  def index
    redirect_to "https://www.google.com/#hl=zh-TW&q=site:awsug.tw+#{params[:q]}"
  end
end
