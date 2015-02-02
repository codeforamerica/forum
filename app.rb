require 'sinatra'
require 'octokit'
require 'sinatra_auth_github'
require 'redcarpet'
require 'json'
require 'time'

enable :sessions

set :github_options, {
  :scopes    => "repo, user:email",
  :secret    => ENV['GITHUB_CLIENT_SECRET'],
  :client_id => ENV['GITHUB_CLIENT_ID'],
}

register Sinatra::Auth::Github
markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, extensions = {autolink: true})

def which_github_client()
  ''' 
    Which github client to use?
    Use the users github api limit if they are logged in
    Use ours for all the lurkers
  '''
  if authenticated?
    client = github_user.api
  end
  if not authenticated?
    client = Octokit
  end
  return client
end

get '/forum' do
  redirect '/forum/codeforamerica/forum'
end

get '/forum/signup' do
  erb :signup
end

get '/forum/signin' do
  authenticate!
  redirect back
end

get '/forum/signout' do
  logout!
  redirect back
end

get '/forum/:username/:repo_name' do
  '''
    A list of all the discussions happening in the main repo.
  '''
  client = which_github_client()
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  @repo = client.repository(@repo_string)
  @labels = client.labels(@repo_string)
  @issues = client.list_issues(@repo_string)
  erb :index
end

get '/forum/:username/:repo_name/new' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  @labels = github_user.api.labels(@repo_string)
  erb :new_issue
end

post '/forum/:username/:repo_name/new' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  github_user.api.create_issue(@repo_string, params[:title], params[:body], options = {:labels => params[:categories]})
  redirect "/forum/#{params[:username]}/#{params[:repo_name]}"
end

get '/forum/:username/:repo_name/:issue_number' do
  client = which_github_client()
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  @issue = client.issue(@repo_string, params[:issue_number])
  @issue.body = markdown.render(@issue.body)
  @comments = client.issue_comments(@repo_string, params[:issue_number])
  @comments.each do |comment|
    comment.body = markdown.render(comment.body)
  end
  @time = Time.now.httpdate
  erb :issue
end

get '/forum/:username/:repo_name/:issue_number/updates' do
    client = which_github_client()
    @repo_string = "#{params[:username]}/#{params[:repo_name]}"
    @time = params["time"]
    @new_comments = []
    @comments = client.issue_comments(@repo_string, params[:issue_number], :since => @time)
    @comments.each do |comment|
        @new_comment = {}
        @new_comment["login"] = comment.user.login
        @new_comment["html_url"] = comment.user.html_url
        @new_comment["body"] = markdown.render(comment.body)
        @new_comments.push(@new_comment)
    end
    return @new_comments.to_json
end

get '/forum/:username/:repo_name/:issue_number/edit' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  @labels = github_user.api.labels(@repo_string)
  @issue = github_user.api.issue(@repo_string, params[:issue_number])
  @label_names = Array.new
  @issue.labels.each do |label|
    @label_names.push(label.name)
  end
  erb :edit
end

post '/forum/:username/:repo_name/:issue_number/edit' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  github_user.api.update_issue(@repo_string, params[:issue_number], params[:title], params[:body], options = {:labels => params[:categories]})
  redirect "/forum/#{@repo_string}/#{params[:issue_number]}"
end

post '/forum/:username/:repo_name/:issue_number/close' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  github_user.api.close_issue(@repo_string, params[:issue_number])
  redirect "/forum/#{@repo_string}"
end

post '/forum/:username/:repo_name/:issue_number/comment' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  github_user.api.add_comment(@repo_string, params[:issue_number], params[:comment])
  redirect "/forum/#{@repo_string}/#{params[:issue_number]}"
end

get '/forum/:username/:repo_name/:issue_number/comment/:comment_id/edit' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  @comment = github_user.api.issue_comment(@repo_string, params[:comment_id])
  erb :edit_comment
end

post '/forum/:username/:repo_name/:issue_number/comment/:comment_id/edit' do
  authenticate!
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  @comment = github_user.api.update_comment(@repo_string, params[:comment_id], params[:body])
  redirect "/forum/#{@repo_string}/#{params[:issue_number]}"
end

get '/forum/:username/:repo_name/l/:label_name' do
  client = which_github_client()
  @repo_string = "#{params[:username]}/#{params[:repo_name]}"
  @labels = client.labels(main_repo)
  @issues = client.list_issues(@repo_string, options = {:labels => params[:label_name]})
  erb :index
end
