class ConversionWorker
  require "sendgrid-ruby"
  require "aws-sdk"
  require "json"
  
  include Shoryuken::Worker
  include SendGrid
  shoryuken_options queue: 'ColaAudiosPorConvertir.fifo', auto_delete: false

  def perform(sqs_msg, body)
    Aws.config.update({ region: "us-east-2" })
    dynamodb = Aws::DynamoDB::Client.new( access_key_id: ENV['Dynamo_KEY'],
                                          secret_access_key: ENV['Dynamo_SECRET'])
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
        begin
          #Codigo de conversion del archivo
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
          @subject = 'Su audio ya es público!'
          @to = Email.new(email: vocess_locutor["emailLocutor"])
          content = Content.new(type: 'text/plain', value: "\n Cordial saludo, " + vocess_locutor["nombresLocutor"] + " " + vocess_locutor["apellidosLocutor"] + 
            "\n\n  Es un placer para nosotros informale que su audio ha sido actualizado al estado activo, por lo cual ya es visible desde nuestro portal.\n 
            Para verlo y reproducirlo por favor acceda a esta url: " + vocess_locutor["convertidaURL"] + "\n Le deseamos la mejor de las suertes en el concurso.\n\n 
            Gracias por hacer parte de este proyecto.\n\n Atentamente: Grupo de trabajo de Publivoz." )
          mail = Mail.new(@from, @subject, @to, content)
          sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'], host: 'https://api.sendgrid.com')
          raise 'A test exception.'
          @response = sg.client.mail._('send').post(request_body: mail.to_json)
        rescue Exception => e
          content = Content.new(type: 'text/plain', value: "\n Cordial saludo, " + vocess_locutor["nombresLocutor"] + " " + vocess_locutor["apellidosLocutor"] + 
            "\n\n  Lamentamos informarle que su audio no pudo ser convertido y se encuentra en estado inactivo, por lo cual aún no es visible desde nuestro portal.\n 
            Intentaremos resolver el problema y le avisaremos cuando su audio este disponible\n Disculpe las molestias.\n\n 
            Agradecemos su comprensión.\n\n Atentamente: Grupo de trabajo de Publivoz." )
          mail = Mail.new(@from, @subject, @to, content)
          @response = sg.client.mail._('send').post(request_body: mail.to_json)
          puts e.message 
        end
        sqs_msg.delete unless should_retry?(sqs_msg, body) 
    end
    puts "Hello: " + body
    puts @response.status_code
    puts @response.body
    puts @response.headers
  end
end
