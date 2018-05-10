class HireFireController < ApplicationController
  def info
    render json: JSON.generate([
      {name: "worker", quantity: 10}
    ])
  end
 end
