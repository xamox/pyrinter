from subprocess import call
import cherrypy

class Root:
  def index(self):
      str = "Web Server Initialized"
      str += "<hr>"
      str += "please visit localhost/printer/ to print"
      str += "<br>"
      str += "what you want printed will be passed as the URL argument"
      str += "<br>"
      str += "(i.e. localhost/printer/print this text)"
      return str
  index.exposed = True
  
  def printtext(self, print_this):
    str = "<hr>"
    str += "<h1><b>Printing</b></h1>"
    str += "<hr>"
    str += "<br>"
    str += "<h2>"
    str += print_this
    str += "</h2>"
    
    cmd = "./pyrint.pl "
    cmd += " " + print_this
    call(cmd, shell=True)

    return str
  printtext.exposed = True

  
root = Root()
cherrypy.quickstart(root)
