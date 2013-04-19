require 'sinatra'
require 'gocardless'
require 'pstore'
require 'yaml'

GC_DETAILS = YAML.load(File.read('gocardless.yml'))

GoCardless.environment = :sandbox
client = GoCardless::Client.new(GC_DETAILS)

def merchants_store
  @merchants_store ||= PStore.new("merchants.store")
end

def load_merchant(id, access_token)
  attrs = { merchant_id: id, token: access_token }
  client = GoCardless::Client.new(GC_DETAILS.merge(attrs))
  client.merchant
end

def gc_redirect_uri
  url("/link-merchant-callback")
end

get "/" do
  merchants_store.transaction do
    @merchants = merchants_store.roots.map do |id|
      token = merchants_store[id]
      load_merchant(id, token)
    end
  end

  erb :index
end

post "/link-merchant" do
  redirect to client.new_merchant_url(redirect_uri: gc_redirect_uri)
end

get "/link-merchant-callback" do
  auth_code = params[:code]
  client.fetch_access_token(auth_code, redirect_uri: gc_redirect_uri)

  merchants_store.transaction do
    merchants_store[client.merchant_id] = client.access_token
  end

  redirect to "/"
end

