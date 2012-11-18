namespace :censusfile do
  def ruby_rake_task(task)
    env    = ENV['RAILS_ENV'] || 'production'
    groups = ENV['RAILS_GROUPS'] || 'assets'
    args   = [$0, task,"RAILS_ENV=#{env}","RAILS_GROUPS=#{groups}"]
    args << "--trace" if Rake.application.options.trace
    ruby *args
  end

  # We are currently running with no explicit bundler group
  # and/or no explicit environment - we have to reinvoke rake to
  # execute this task.
  def invoke_or_reboot_rake_task(task)
    if ENV['RAILS_GROUPS'].to_s.empty? || ENV['RAILS_ENV'].to_s.empty?
      ruby_rake_task task
    else
      Rake::Task[task].invoke
    end
  end

  def index_path
    File.join(Rails.public_path, 'index.html')
  end

  desc 'Delete "public" files'
  task :clean => [ 'assets:environment', 'assets:clean' ] do
    rm_rf(index_path)
  end

  desc 'Render "public" files (index.html and assets)'
  task :render_public do
    invoke_or_reboot_rake_task "censusfile:render_public:all"
  end

  task :publish do
    invoke_or_reboot_rake_task "censusfile:render_public:all"

    `scp -r public/* censusfile:/opt/censusfile/public/`

    Rake::Task['censusfile:clean'].invoke
  end

  namespace :render_public do
    task :all => [ 'assets:environment', 'assets:precompile:primary' ] do
      class TaskActionView < ActionView::Base
        include Rails.application.routes.url_helpers
        include ::ApplicationHelper

        def default_url_options
          { host: 'censusfile.adamhooper.com' }
        end
      end

      def action_view
        controller = ActionController::Base.new
        controller.request = ActionDispatch::TestRequest.new
        context = ActionView::LookupContext.new(ActionController::Base.view_paths)
        TaskActionView.new(context, {}, controller)
      end

      data = action_view.render(:template => 'map/show', :layout => 'layouts/application')
      File.open(index_path, 'w') { |f| f.write(data) }
    end
  end
end
