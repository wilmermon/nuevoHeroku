class ConversionWorker
  require "sendgrid-ruby"
  require "aws-sdk"
  require "json"
  require "streamio-ffmpeg"
  
  include Shoryuken::Worker
  include SendGrid
  shoryuken_options queue: 'ColaAudiosPorConvertir.fifo', auto_delete: false

  def perform(sqs_msg, body)
    Aws.config.update({ region: "us-east-2" })
    dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                          secret_access_key: ENV['Dynamo_SECRET'])
    s3_client = Aws::S3::Client.new( access_key_id: ENV['S3_KEY'],
                                          secret_access_key: ENV['S3_SECRET'])
    
    table_name = 'vocess_locutors'
    parameter = {
        table_name: table_name,
        index_name: 'id-estado-index',
        select: 'ALL_PROJECTED_ATTRIBUTES',
        key_condition_expression: "id = :vozId and estado = :est",
        expression_attribute_values: {
            ":vozId" => body,
            ":est" => 'En proceso'
        }
    }

    @vocess_locutors = dynamodb.query(parameter)
    @vocess_locutors.items.each do |vocess_locutor|
      
        path_vocess_locutor = vocess_locutor["originalURL"][0, vocess_locutor["originalURL"].index('?')]
        pathConvert = path_vocess_locutor[0, path_vocess_locutor.length - 3].gsub('cache','store') + "mp3" 
        fileName = path_vocess_locutor[path_vocess_locutor.index('cache') + 6, path_vocess_locutor.length]
        s3_client.get_object(bucket: ENV['S3_BUCKET'], key: fileName, response_target: '/temp/' + fileName)
        movie = FFMPEG::Movie.new('/temp/' + fileName)
        options = {:video_codec => "libx264", :frame_rate => 10, :resolution => "320x240", :video_bitrate => 300, :video_bitrate_tolerance => 100,
             :croptop => 60, :cropbottom => 60, :cropleft => 10, :cropright => 10, :aspect => 1.333333, :keyframe_interval => 90,
             :audio_codec => "libfaac", :audio_bitrate => 32, :audio_sample_rate => 22050, :audio_channels => 1,
             :threads => 2,
             :custom => "-flags +loop -cmp +chroma -partitions +parti4x4+partp8x8 -flags2 +mixed_refs -me_method umh -subq 6 -refs 6 -rc_eq 'blurCplx^(1-qComp)' -coder 0 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -level 21"}
        movie.transcode('/temp/' + fileName[0, fileName.length - 3]+'mp3', options)
        obj = s3_client.bucket(ENV['S3_BUCKET']).object(fileName)
        # Metadata to add
        #metadata = {"answer" => "42"}
        # Upload it      
        obj.upload_file('store'/+ fileName)
        #Codigo de conversion del archivo
       begin
        params = {
          table_name: table_name,
          key: {
              concurso_id: vocess_locutor["concurso_id"],
              id: vocess_locutor["id"]
          },
          update_expression: "set estado = :est, convertidaURL = :pathConvert, updated_at = :update",
          expression_attribute_values: {
              ":est" => 'Convertida',
              ":pathConvert" => pathConvert,
              ":update" => Time.now.to_s
          },
          return_values: "UPDATED_NEW"
        }               
        result = dynamodb.update_item(params)
        @from = Email.new(email: 'publivoz@publivoz.com')
        subject = 'Su audio ya es público!'
        @to = Email.new(email: vocess_locutor["emailLocutor"])
        content = Content.new(type: 'text/plain', value: "\nCordial saludo, " + vocess_locutor["nombresLocutor"] + " " + vocess_locutor["apellidosLocutor"] + 
          "\n\nEs un placer para nosotros informale que su audio ha sido actualizado al estado activo, por lo cual ya es visible desde nuestro portal.\n
Para verlo y reproducirlo por favor acceda a esta url: " + vocess_locutor["convertidaURL"] + "\nLe deseamos la mejor de las suertes en el concurso.\n\n
Gracias por hacer parte de este proyecto.\n\nAtentamente: Grupo de trabajo de Publivoz." )
        mail = Mail.new(@from, subject, @to, content)
        sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'], host: 'https://api.sendgrid.com')
        @response = sg.client.mail._('send').post(request_body: mail.to_json)
      rescue Exception => e
        subject = 'Su audio no pudo convertirse!'
        content = Content.new(type: 'text/plain', value: "\nCordial saludo, " + vocess_locutor["nombresLocutor"] + " " + vocess_locutor["apellidosLocutor"] + 
          "\n\nLamentamos informarle que su audio no pudo ser convertido y se encuentra en estado inactivo, por lo cual aún no es visible desde nuestro portal.\n
Intentaremos resolver el problema y le avisaremos cuando su audio este disponible.\nDisculpe las molestias.\n\nAgradecemos su comprensión.\n\nAtentamente: Grupo de trabajo de Publivoz." )
        mail = Mail.new(@from, subject, @to, content)
        #@response = sg.client.mail._('send').post(request_body: mail.to_json)
        puts e
      end
      sqs_msg.delete unless should_retry?(sqs_msg, body) 
    end
    puts "Hello: " + body
  end
end
