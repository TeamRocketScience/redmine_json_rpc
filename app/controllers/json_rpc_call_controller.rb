class JsonRpcCallController < ApplicationController
  unloadable

  before_filter :require_admin
  before_filter :authorize_global
  accept_api_auth :handle_rpc_request  

  def handle_rpc_request
    if request.post?
      begin
        rpc = JSON.parse(request.raw_post) rescue JSON.parse(URI.decode(request.raw_post))
        raise "User not found" if User.find_by_api_key(params["key"]).nil?
        model = ActiveRecord::Base.send(:subclasses).find { |m| m.to_s == rpc["class"] }
        unless model.nil?
          logger.info *rpc["params"].count
          begin
            ans = self.send("process_#{rpc["class"].underscore}", model, rpc)
          rescue
            logger.info "raised"
            ans = model.send(rpc["method"], *rpc["params"])
          end
          unless ans.nil?
            if (ans.respond_to? :errors) && (!ans.errors.empty?)
              respond_to do |format| 
                format.json { render :json => { "error" => ans.errors.full_messages.join('; ') } }
              end   
            else
              respond_to { |format| format.json { render :json => ans } }
            end
          else
            respond_to { |format| format.json {render :json => { "error" => "Something went wrong" } } }
          end
        end
      rescue Exception => e
        respond_to do |format|
          format.json { render :json => { "error" => e.to_s } }
        end
      end
    end
  end 
  
  private

  def process_issue(model, rpc)
    logger.info rpc["method"]
    logger.info rpc["params"]
    if rpc["method"].include? "find"
      ans =  model.send(rpc["method"], *rpc["params"])
      hours = TimeEntry.find_all_by_issue_id(rpc["params"][0]).inject {|a, b| a.hours + b.hours}
      relations = ans.relations
      ans = JSON.parse(ans.to_json)
      ans["spent_hours"] = hours
      ans["relations"] = relations
      return ans
    else
      raise
    end
  end

  def process_issue_relation(model, rpc)
    logger.info rpc["method"] 
    if rpc["method"].include? "create"
      ans = IssueRelation.new 
      ans.issue_from = Issue.find(rpc["params"][0]["issue_from_id"])
      ans.issue_to = Issue.find(rpc["params"][0]["issue_to_id"])
      ans.relation_type = rpc["params"][0]["relation_type"]
      ans.save
      return ans
    else
      raise
    end
  end

end
