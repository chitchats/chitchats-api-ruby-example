# frozen_string_literal: true

require "ActiveResource"

CLIENT_ID = 999999
ACCESS_TOKEN = "PASTE_ACCESS_TOKEN_HERE"

class BaseResource < ActiveResource::Base
  self.site = "https://chitchats.com/api/v1/clients/#{CLIENT_ID}"
  self.headers["Authorization"] = ACCESS_TOKEN
end

class Batch < BaseResource
  has_many :shipments
end

class Shipment < BaseResource
  class << self
    def add_shipments_to_batch(batch_id:, shipment_ids:)
      patch(:add_to_batch, batch_id: batch_id, shipment_ids: shipment_ids)
    end

    def remove_shipments_from_batch(shipment_ids:)
      patch(:remove_from_batch, shipment_ids: shipment_ids)
    end
  end

  belongs_to :batch

  def buy
    patch(:buy)

    # Buying postage can take a few seconds to process and generate a label
    # so block and poll until we know it doesn't fail.
    sleep(0.5) while reload.status == "postage_requested"
    raise "Purchase postage failed" if status == "postage_purchase_failed"

    status
  end

  def refund
    patch(:refund)
    reload
  end
end

class ActiveResource::ConnectionError < StandardError
  def to_s
    "Error #{response.code}: #{JSON.parse(response.body)["message"]}"
  end
end

# Uncomment the next 3 lines to use API on a console
# require "pry"
# binding.pry
# return

# create new batch
print "Creating new batch... "
batch = Batch.create
puts "batch_id: #{batch.id}"

print "Fetching all batches... "
batches = Batch.all
puts "count: #{batches.count}"

# show batch
print "Fetching batch #{batch.id} status... "
batch = Batch.find(batches.first.id)
puts batch.status

# create new shipment
print "Creating first shipment... "
shipment_1 = Shipment.create(
  name: "John Doe",
  address_1: "123 ANYWHERE ST.",
  city: "Vancouver",
  province_code: "BC",
  postal_code: "V6K 1A1",
  country_code: "CA",
  description: "Hand made bracelet",
  value: "85",
  value_currency: "usd",
  package_type: "parcel",
  size_unit: "cm",
  size_x: 10,
  size_y: 5,
  size_z: 2.5,
  weight_unit: "g",
  weight: 250,
  insurance_requested: true,
  postage_type: "chit_chats_canada_tracked",
  ship_date: "today"
)
puts shipment_1.id

print "Creating second shipment... "
shipment_2 = Shipment.create(
  name: "Mary Jane",
  address_1: "413 South Eighth Street",
  city: "Springfield",
  province_code: "IL",
  postal_code: "62701-1905",
  country_code: "US",
  description: "Hand made necklace",
  value: "50",
  value_currency: "usd",
  package_type: "parcel",
  size_unit: "cm",
  size_x: 7,
  size_y: 5.5,
  size_z: 1.3,
  weight_unit: "oz",
  weight: 10.3,
  postage_type: "usps_first",
  insurance_requested: false,
  signature_requested: true,
  ship_date: "today"
)
puts shipment_2.id

print "Fetching all pending shipments... "
shipments = Shipment.where(status: "pending")
puts shipments.count

print "Adding shipments to batch... "
Shipment.add_shipments_to_batch(batch_id: batch.id, shipment_ids: [shipment_1.id, shipment_2.id])
puts "OK"

print "Testing batch associations... "
puts batch.reload.shipments.count

print "Testing shipment associations... "
puts shipment_1.reload.batch.status

print "Removing shipments from batch... "
Shipment.remove_shipments_from_batch(shipment_ids: [shipment_1.id, shipment_2.id])
puts "OK"

print "Destroying batch #{batch.id}... "
batch.destroy
puts "OK"

# print "Buying shipment 1 postage... "
# shipment_1.buy
# puts "OK"

# # A number of background tasks need to run after purchasing postage which may
# # prevent the postage from being able to be refunded immediately after
# # buying postage. Sleep for a few seconds to let these operations complete.
# # Not doing this may result in a `Resource in use, please try again` error.
# print "Waiting 2 seconds before refunding... "
# sleep 2
# puts "OK"

# print "Refunding shipment 1 postage... "
# shipment_1.refund
# puts "OK"

print "Deleting shipment 2... "
shipment_2.destroy
puts "OK"
