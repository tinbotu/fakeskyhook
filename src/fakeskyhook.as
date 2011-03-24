import com.adobe.serialization.json.JSON;

import flash.events.Event;
import flash.events.SecurityErrorEvent;
import flash.net.URLLoader;
import flash.net.URLRequest;

import libspinner.LoadingPicture;

import mx.collections.ArrayCollection;
import mx.controls.Alert;
import mx.core.UIComponent;
import mx.events.ListEvent;
import mx.utils.StringUtil;

private var regex_macaddr:RegExp;

private static var requestSkyhook:String=<><![CDATA[
<LocationRQ xmlns='http://skyhookwireless.com/wps/2005' version='2.6' street-address-lookup='full'>
  <authentication version='2.0'>
    <simple>
      <username>beta</username>
      <realm>js.loki.com</realm>
    </simple>
  </authentication>
  <access-point>
    <mac>{0}</mac>
    <signal-strength>-46</signal-strength>
  </access-point>
</LocationRQ>]]></>;

private static const requestGoogle:String=<><![CDATA[{"version":"1.1.0","request_address":true,"wifi_towers":[{"mac_address":"{0}","ssid":"","signal_strength":-50}]}]]></>;
private static const apiUrlSkyhook:String = "https://api.skyhookwireless.com/wps2/location";
private static const apiUrlProxy:String = "http://0x00.be/tech/macaddrfinder/proxy.php?url=https://www.google.com/loc/json";
private static const apiUrlGoogle:String = "https://www.google.com/loc/json";

private var urlRequest:URLRequest;
private var urlLoader:URLLoader;
private var running:Boolean;
public var loadingIcon:LoadingPicture;


public function setStatus(str:String):void{
	this.status.text = "Status: " + str;
}

public function setSpin(b:Boolean):void{
  this.running = loadingIcon.visible = b;
  if(b) cancel.label = "cancel";
  else  cancel.label = "clear";
}

public function macaddrfinder_():void
{
	this.regex_macaddr = new RegExp("^([0-9a-fA-F]{2})[.:-]?([0-9a-fA-F]{2})[.:-]?([0-9a-fA-F]{2})[.:-]?([0-9a-fA-F]{2})[.:-]?([0-9a-fA-F]{2})[.:-]?([0-9a-fA-F]{2})$", "g");
	messages.text="";
	this.urlRequest = new URLRequest(); 

	loadingIcon = new LoadingPicture(9, 15, 1, 5, 868686, 868686);
	loadingIcon.visible = false;
	this.running = false;
	loadingIcon.show(parent , 481, 24);
	loadingIcon.start();
	cancel.label = "clear";
	setStatus("ready");
}

private function requestComplete(ev:Event):void
{
	var loader:URLLoader = URLLoader(ev.target);
	var geo:Object = JSON.decode(loader.data);
	// messages.text += loader.data;
	messages.text += "got " + loader.dataFormat + " " + loader.bytesLoaded + "bytes\n";
	trace(loader.data);
	
	try{
		messages.text +="location: " + geo["location"]["latitude"] + ", " +geo["location"]["longitude"]+", "+geo["location"]["accuracy"];
		ExternalInterface.call("dropPin",  geo["location"]["latitude"] , geo["location"]["longitude"],  geo["location"]["accuracy"]);
		setStatus("ready");
		setSpin(false);
		qth.text = geo["location"]["latitude"] + ", " +geo["location"]["longitude"] +"; ";
		try{
		 qth.text += 	(geo["location"]["address"]["street_number"] ? geo["location"]["address"]["street_number"] + ", " : "") +
								(geo["location"]["address"]["street"] ? geo["location"]["address"]["street"] + ", "  : "") +
								(geo["location"]["address"]["city"] ? geo["location"]["address"]["city"] + ", "  : "") +
								(geo["location"]["address"]["region"] ? geo["location"]["address"]["region"] + ", " : "")  +
								(geo["location"]["address"]["country"] ? geo["location"]["address"]["country"] : "")   			
							;
		}
		catch(e:*){}
		loader.close();
	}
	catch(error:*){
		ExternalInterface.call("clearPin");
		setStatus("Not found");
		setSpin(false);
		messages.text="";
	}
	setSpin(false);
	execute.enabled = true;
	this.urlLoader=null;
}

private function requestSecurityError(ev:flash.events.SecurityErrorEvent):void
{
	execute.enabled = true;
	setSpin(false);
	setStatus("error");
	qth.text="";
	messages.text = "** Try proxy **\n";
	messages.text += ev.toString();
}

private function requestIOError(ev:IOErrorEvent):void
{
	setStatus("http error");
	qth.text="";
	messages.text +=  ev;
	setSpin(false);
	checkform();
	this.urlLoader = null;
}

private function buildRequest():void
{
	messages.text = 'Interesting MAC address: ' + macaddr.text +"\n";
	qth.text="";

	var mac:String = macaddr.text.replace(this.regex_macaddr, "$1-$2-$3-$4-$5-$6");
	ExternalInterface.call("clearPin");
	if(mac == ''){
		setSpin(false);
		cancel.enabled = false;
		setStatus("invalid format MAC address");
		return;
	}

	try{
		this.urlLoader = new URLLoader();
	}
	catch(e:Error){
		messages.text += e.message;
		setStatus("error: URLLoader");
		execute.enabled = true;
		cancel.enabled = false;
		setSpin(false);
		return;
	}
	urlLoader.addEventListener(Event.COMPLETE, requestComplete);
	urlLoader.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, requestSecurityError);
	urlLoader.addEventListener(IOErrorEvent.IO_ERROR, requestIOError);
	
	urlRequest.url = useproxy.selected ? apiUrlProxy : apiUrlGoogle;
	urlRequest.contentType="text/plain";
	urlRequest.method = URLRequestMethod.POST;
	urlRequest.data = StringUtil.substitute(requestGoogle, mac).replace(/\r\n/g, "") ;

	try{
		urlLoader.load(urlRequest);
		setStatus("requesting...");
		setSpin(true);
		execute.enabled = false;
	}
	catch(error:*){
		setStatus("http error");
		messages += error.toString();
		execute.enabled = true;
		setSpin(false);
		checkform();
	}
}

private function uiReady():void
{
	setSpin(false);
	qth.text="";
	cancel.label = "clear";
	checkform();
}

protected function useproxy_clickHandler(event:MouseEvent):void
{
	/*
	if(useproxy.selected){
		Alert.show("**Warning**\n1. it's Slow.\n2.Don't pound buttons plase, or google may ban my ip address ;(");
	}
	*/
}

protected function execute_clickHandler(event:MouseEvent):void
{
	buildRequest();
	checkform();
}

protected function cancel_clickHandler(event:MouseEvent):void
{
	if(! this.running){
		macaddr.text = "";
	}
	if(this.urlLoader)
	{
		urlLoader.close();
		uiReady();
		setStatus("abort");
		messages.text = "";
	}
	checkform();
}

private function checkform():void
{
	if(! this.running){
		if(macaddr.text.length > 0) cancel.enabled = true;
		else 										  cancel.enabled = false;
	}

	if(this.regex_macaddr.test(macaddr.text)){
		execute.enabled = true;
	} 
	else{
		execute.enabled = false;
	}
}

protected function macaddr_changeHandler(event:Event):void
{
	this.checkform();
}
