web: bundle exec puma -C config/puma.rb
worker: bundle exec shoryuken -q ColaAudiosPorConvertir.fifo -r ./app/workers/conversion_worker.rb -C config/shoryuken.yml
