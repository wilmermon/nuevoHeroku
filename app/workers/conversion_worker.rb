class ConversionWorker
  include Shoryuken::Worker
  require "aws-sdk"
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
        begin
          raise 'A test exception.'
        rescue Exception => e  
          puts e.message 
        end
        sqs_msg.delete unless should_retry?(sqs_msg, body) 
    end
    puts "Hello: " + body
  end
end
