class ChangePrefix < Plugin
  def initialize
    super
    @prefix = '!'
  end

  def help(_plugin, _topic = '')
    '!prefix <new prefix> - Changes the prefix used for commands'
  end

  def on_privmsg(m)
    return unless m.params[0] == @bot.nick
    return unless m.message.split(' ')[0] =~ /^#{@prefix}prefix/
  end
end
