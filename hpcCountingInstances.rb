require 'rubygems'
require 'fog'
require 'graphite-api'
require 'json'
#require 'colored'
#require 'simple-graphite'

# Silly script to get HP Instance count by PPK value, and Instance state
# Dependent on HP Fog
conn = Fog::Compute.new(
       :provider      => "HP",
       :hp_account_id  => "---",
       :hp_secret_key =>  "---",
       :hp_auth_uri   =>  "https://---,/v2.0/tokens",
       :hp_tenant_id =>   "---",
       :hp_avl_zone =>    "---",,
       :hp_use_upass_auth_style => "---",)

######
#HPC Private connection Account Info goes here
######

# Get all instances
  instances = conn.servers # initialized from above
  puts "Total instances detected #{instances.size}"

# Define hash as place holders for data and pull data from HP Console
  total_instance, held_machines = Hash.new(0), Hash.new(0)
  instance_owners = conn.servers

# Get List of Instance 'owners' by PPK name
  result = instance_owners.inject([]) { |result,h| result << h.key_name unless result.include?(h.key_name); result }

# Create Hash of Total Instances owned by each PPK that are also in active state aka running
  result.each do |v| instance_owners.each do |n| 
	held_machines[v] +=1 if v == n.key_name && n.state=~/ACTIVE/ 
	# total_instance[v] +=1 if v == n.key_name -- not needed.
	end
 end

# Serve up results in JSON
  puts held_machines.to_json