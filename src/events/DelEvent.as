package events
{
	import flash.events.Event;
	
	
	/**
	 * 
	 * @author DOM
	 */
	public class DelEvent extends Event
	{
		public static const DELETE:String = "delete";
		
		public function DelEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		/**
		 * 导出类名
		 */		
		public var data:Object;
		
		public var itemIndex:int;
	}
}