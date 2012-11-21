package events
{
	import flash.events.Event;
	
	
	/**
	 * 
	 * @author DOM
	 */
	public class SearchEvent extends Event
	{
		public static const SEARCH_RES:String = "searchRes";
		
		public function SearchEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
		public var keyList:Array;
	}
}