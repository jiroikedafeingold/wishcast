#!/usr/bin/env ruby
# encoding: utf-8
#
# Uploads what deliver can't (yet) to an App Store version, in every localization:
#   - iPhone Duo screenshots, from fastlane/screenshots_duo/<locale>/ (fastlane 2.237 aborts on Duo sizes)
#   - the creative assets: product page header and search results images, from fastlane/creative_assets/
#
#   source ~/Projects/AppStoreConnect/credentials.env
#   tools/upload-store-extras.rb 1.0.12
#
# Run it after deliver: deliver's overwrite deletes every screenshot set it finds, Duo included.
# Each run replaces what it uploads (old Duo sets and old placements are deleted first). The version
# must be editable (not waiting for review).

require "openssl"; require "base64"; require "json"; require "net/http"; require "digest"

BUNDLE_ID = "com.jirofeingold.Wishcast"
ROOT = File.expand_path("..", __dir__)
DUO_DIR = File.join(ROOT, "fastlane", "screenshots_duo")
HEADER = File.join(ROOT, "fastlane", "creative_assets", "wishcast_header_3840x1646.png")
SEARCH = File.join(ROOT, "fastlane", "creative_assets", "wishcast_search_3840x2560.png")
KEY = OpenSSL::PKey::EC.new(File.read(ENV.fetch("ASC_KEY_PATH")))

def b64(d) = Base64.urlsafe_encode64(d).delete("=")
def token
  h = b64({alg: "ES256", kid: ENV.fetch("ASC_KEY_ID"), typ: "JWT"}.to_json)
  c = b64({iss: ENV.fetch("ASC_ISSUER_ID"), exp: Time.now.to_i + 900, aud: "appstoreconnect-v1"}.to_json)
  der = KEY.sign(OpenSSL::Digest.new("SHA256"), "#{h}.#{c}")
  raw = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }.join
  "#{h}.#{c}.#{b64(raw)}"
end
def api(klass, path, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  r = klass.new(uri); r["Authorization"] = "Bearer #{token}"
  if body then r["Content-Type"] = "application/json"; r.body = body.to_json end
  res = Net::HTTP.start(uri.host, 443, use_ssl: true) { |http| http.request(r) }
  [res.code.to_i, (JSON.parse(res.body) rescue {})]
end
def get(path) = api(Net::HTTP::Get, path)[1]
def check!(code, body, what)
  return body if code.between?(200, 299)
  abort "#{what} failed (#{code}): #{(body["errors"] || []).map { |e| e["detail"] }.join(" | ")}"
end

# Sends the file's bytes to the upload operations Apple handed back (no bearer token on these).
def send_parts(operations, data)
  operations.each do |op|
    uri = URI(op["url"])
    r = Net::HTTP.const_get(op["method"].capitalize).new(uri)
    (op["requestHeaders"] || []).each { |h| r[h["name"]] = h["value"] }
    r.body = data.byteslice(op["offset"], op["length"])
    res = Net::HTTP.start(uri.host, 443, use_ssl: true) { |http| http.request(r) }
    abort "upload part failed (#{res.code})" unless res.code.to_i < 300
  end
end

version = ARGV[0] or abort "usage: upload-store-extras.rb <version>"
app = get("/v1/apps?filter[bundleId]=#{BUNDLE_ID}").dig("data", 0, "id") or abort "app not found"
v = get("/v1/apps/#{app}/appStoreVersions?filter[platform]=IOS&limit=8")["data"]
    .find { |x| x.dig("attributes", "versionString") == version } or abort "no iOS #{version} record"
localizations = get("/v1/appStoreVersions/#{v["id"]}/appStoreVersionLocalizations?limit=50")["data"]

# --- iPhone Duo screenshots ---------------------------------------------------------------------
localizations.each do |loc|
  locale = loc.dig("attributes", "locale")
  files = Dir[File.join(DUO_DIR, locale, "*.png")].sort
  next if files.empty?
  get("/v1/appStoreVersionLocalizations/#{loc["id"]}/appScreenshotSets")["data"]
    .select { |s| s.dig("attributes", "screenshotDisplayType") == "APP_IPHONE_DUO" }
    .each { |s| api(Net::HTTP::Delete, "/v1/appScreenshotSets/#{s["id"]}") }
  code, set = api(Net::HTTP::Post, "/v1/appScreenshotSets", {data: {type: "appScreenshotSets",
    attributes: {screenshotDisplayType: "APP_IPHONE_DUO"},
    relationships: {appStoreVersionLocalization: {data: {type: "appStoreVersionLocalizations", id: loc["id"]}}}}})
  set_id = check!(code, set, "#{locale} Duo set")["data"]["id"]
  files.each do |file|
    data = File.binread(file)
    code, shot = api(Net::HTTP::Post, "/v1/appScreenshots", {data: {type: "appScreenshots",
      attributes: {fileName: File.basename(file), fileSize: data.bytesize},
      relationships: {appScreenshotSet: {data: {type: "appScreenshotSets", id: set_id}}}}})
    shot = check!(code, shot, "#{locale} #{File.basename(file)} reserve")["data"]
    send_parts(shot.dig("attributes", "uploadOperations"), data)
    code, body = api(Net::HTTP::Patch, "/v1/appScreenshots/#{shot["id"]}", {data: {type: "appScreenshots", id: shot["id"],
      attributes: {uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(data)}}})
    check!(code, body, "#{locale} #{File.basename(file)} commit")
  end
  puts "#{locale}: #{files.size} Duo screenshots"
end

# --- Creative assets ------------------------------------------------------------------------------
library = get("/v1/apps/#{app}/assetLibrary").dig("data", "id") or abort "no asset library"

# Uploads an image into the app's asset library and waits until Apple has processed it.
def library_image(library, path)
  data = File.binread(path)
  code, image = api(Net::HTTP::Post, "/v1/appAssetLibraryImages", {data: {type: "appAssetLibraryImages",
    attributes: {category: "CREATIVE_ASSETS", fileName: File.basename(path), fileSize: data.bytesize},
    relationships: {assetLibrary: {data: {type: "appAssetLibraries", id: library}}}}})
  image = check!(code, image, "#{File.basename(path)} reserve")["data"]
  send_parts(image.dig("attributes", "uploadOperations"), data)
  code, body = api(Net::HTTP::Patch, "/v1/appAssetLibraryImages/#{image["id"]}",
                   {data: {type: "appAssetLibraryImages", id: image["id"], attributes: {uploaded: true}}})
  check!(code, body, "#{File.basename(path)} commit")
  60.times do
    state = get("/v1/appAssetLibraryImages/#{image["id"]}").dig("data", "attributes", "state")
    puts "  #{File.basename(path)}: #{state}" if state =~ /FAIL|ERROR|REJECT/
    abort "#{File.basename(path)} processing failed" if state =~ /FAIL|ERROR|REJECT/
    return image["id"] unless %w[AWAITING_UPLOAD UPLOAD_COMPLETE PROCESSING].include?(state)
    sleep 5
  end
  abort "#{File.basename(path)} still processing"
end

images = {"PRODUCT_PAGE_HEADER_ASSET" => library_image(library, HEADER),
          "APP_STORE_SEARCH_RESULTS_ASSET" => library_image(library, SEARCH)}
puts "creative assets uploaded to the asset library"

# The art has no text, so every localization shows the same two images.
localizations.each do |loc|
  locale = loc.dig("attributes", "locale")
  existing = get("/v1/appStoreVersionLocalizations/#{loc["id"]}/placements?limit=200")
  (existing["data"] || []).each do |p|
    api(Net::HTTP::Delete, "/v1/appAssetLibraryPlacements/#{p["id"]}") if images.key?(p.dig("attributes", "placementType"))
  end
  images.each do |placement, image_id|
    code, body = api(Net::HTTP::Post, "/v1/appAssetLibraryPlacements", {data: {type: "appAssetLibraryPlacements",
      attributes: {placementType: placement},
      relationships: {appStoreVersionLocalization: {data: {type: "appStoreVersionLocalizations", id: loc["id"]}},
                      image: {data: {type: "appAssetLibraryImages", id: image_id}}}}})
    check!(code, body, "#{locale} #{placement}")
  end
  puts "#{locale}: header + search results placed"
end
