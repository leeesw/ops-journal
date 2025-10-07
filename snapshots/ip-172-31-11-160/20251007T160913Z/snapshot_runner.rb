require "json"
out = ENV["SNAPSHOT_OUT"] or abort "SNAPSHOT_OUT not set"
Dir.mkdir(out) unless Dir.exist?(out)

def safe_write(path, content)
  File.write(path, content)
rescue => e
  File.write(path.sub(/\.\w+$/, ".error"), "#{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
end

# Rails / Ruby / Sidekiq 버전
begin
  info = {
    rails: (defined?(Rails) && Rails.respond_to?(:version)) ? Rails.version : nil,
    ruby:  RUBY_VERSION,
    sidekiq: (defined?(Sidekiq) && Sidekiq.const_defined?(:VERSION)) ? Sidekiq::VERSION : nil,
    env: (defined?(Rails) ? Rails.env : ENV["RAILS_ENV"]),
    app_class: (defined?(Rails) ? Rails.application.class.name : nil)
  }
  safe_write(File.join(out, "rails_info.json"), JSON.pretty_generate(info))
rescue => e
  safe_write(File.join(out, "rails_info.error"), "#{e.class}: #{e.message}")
end

# Sidekiq 프로세스/큐/크론
begin
  require "sidekiq/api"
  ps = Sidekiq::ProcessSet.new
  csv = +"tag,pid,concurrency,queues\n"
  ps.each do |p|
    tag = p["tag"] || p["identity"]
    csv << "#{tag},#{p["pid"]},#{p["concurrency"]},#{Array(p["queues"]).join("/")}\n"
  end
  safe_write(File.join(out, "sidekiq_processes.csv"), csv)

  queues = Sidekiq::Queue.all.sort_by(&:name).map { |q| {name: q.name, size: q.size, latency_s: q.latency} }
  safe_write(File.join(out, "sidekiq_queues.json"), JSON.pretty_generate(queues))
rescue => e
  safe_write(File.join(out, "sidekiq_api.error"), "#{e.class}: #{e.message}")
end

begin
  # sidekiq-cron이 있으면 잡 리스트
  begin
    require "sidekiq/cron/job"
    jobs = Sidekiq::Cron::Job.all.map { |j| {name: j.name, klass: j.klass, cron: j.cron, queue: j.queue, active: j.status == "enabled"} }
    safe_write(File.join(out, "sidekiq_cron.json"), JSON.pretty_generate(jobs))
  rescue LoadError
    # 미사용
  end
end

# DB 상태
begin
  mc = ActiveRecord::Base.connection.migration_context
  status = {
    connected: true,
    current_version: mc.current_version,
    pending_migrations: mc.needs_migration?
  }
  safe_write(File.join(out, "db_status.json"), JSON.pretty_generate(status))
rescue => e
  safe_write(File.join(out, "db_status.error"), "#{e.class}: #{e.message}")
end

# Redis 핑
begin
  require "redis"
  url = ENV["REDIS_URL"] || "redis://127.0.0.1:6380/1"
  pong = Redis.new(url: url).ping
  safe_write(File.join(out, "redis_status.txt"), "url=#{url}\nping=#{pong}\n")
rescue => e
  safe_write(File.join(out, "redis_status.error"), "#{e.class}: #{e.message}")
end

# S3(선택) - 버킷 이름이 ENV에 있으면 head_bucket만
begin
  bucket = ENV["S3_BUCKET"] || ENV["AWS_S3_BUCKET"]
  if bucket
    begin
      require "aws-sdk-s3"
      Aws::S3::Client.new.head_bucket(bucket: bucket)
      safe_write(File.join(out, "s3_status.txt"), "bucket=#{bucket}\nhead_bucket=ok\n")
    rescue LoadError
      safe_write(File.join(out, "s3_status.txt"), "bucket=#{bucket}\naws-sdk-s3 gem not installed\n")
    rescue => e
      safe_write(File.join(out, "s3_status.error"), "#{e.class}: #{e.message}")
    end
  else
    safe_write(File.join(out, "s3_status.txt"), "bucket=(unset)\n")
  end
end

# 라우트/잡 클래스(요약)
begin
  routes = Rails.application.routes.routes.map{|r| {verb: r.verb&.source, path: r.path.spec.to_s, ctrl: r.defaults[:controller], action: r.defaults[:action]} }
  safe_write(File.join(out, "routes.json"), JSON.pretty_generate(routes.take(300))) # 과다 방지
rescue => e
  safe_write(File.join(out, "routes.error"), "#{e.class}: #{e.message}")
end
