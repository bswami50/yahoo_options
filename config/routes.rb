Rails.application.routes.draw do
  get 'yahoo/index' 
  root 'yahoo#index' 
  
  get  "/fetchOptionData"      => "yahoo#index"
  post "/clearData"            => "yahoo#clearData"
  
  post "fetchOptionData"       => "yahoo#fetchOptionData"
  post "clearData"             => "yahoo#clearData"
end
