/* this is an extension of the Flare Job Voyager example, which can be found at
http://flare.prefuse.org/apps/job_voyager
*/

package {
	import flare.apps.App;
	import flare.data.DataSet;
	import flare.data.DataSource;
	import flare.display.TextSprite;
	import flare.util.Shapes;
	import flare.util.Strings;
	import flare.util.palette.ColorPalette;
	import flare.vis.Visualization;
	import flare.vis.controls.ClickControl;
	import flare.vis.controls.HoverControl;
	import flare.vis.controls.TooltipControl;
	import flare.vis.data.Data;
	import flare.vis.data.DataSprite;
	import flare.vis.data.NodeSprite;
	import flare.vis.events.SelectionEvent;
	import flare.vis.events.TooltipEvent;
	import flare.vis.operator.filter.VisibilityFilter;
	import flare.vis.operator.label.StackedAreaLabeler;
	import flare.vis.operator.layout.StackedAreaLayout;
	import flare.widgets.ProgressBar;
	
	import flash.display.Shape;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.net.URLLoader;
	import flash.text.TextFormat;
		

	[SWF(backgroundColor="#ffffff", frameRate="30")]
	public class WeblogsViz extends App
	{
		private var _bar:ProgressBar;
		private var _bounds:Rectangle;
		private var _url:String = "data.txt";
		
		private var _cols:Array;
		private var _vis:Visualization;
		private var _labelMask:Shape;
		private var _stackedLayout:StackedAreaLayout;
		private var _toggleLink:TextSprite;
		
		private var _absoluteMode:Boolean = true;
		private var _filteredController:String = null;
		
		
		protected override function init():void
		{
			addChild(_bar = new ProgressBar());
			var ds:DataSource = new DataSource(_url, "tab");
			var ldr:URLLoader = ds.load();
			_bar.loadURL(ldr, function():void {
				// get loaded data, reshape for stacked columns
  				var ds:DataSet = ldr.data as DataSet;
  				_cols = extractColumns(ds.nodes.data,"date");
            	var dr:Array = reshape(ds.nodes.data, ["controller","action"],"date","hits", _cols,false);
            	var agg: Array = aggregateData(dr,"controller",_cols);
            	visualize(Data.fromArray(dr.concat(agg)));
    			_bar = null;
			});
		}
		
		private function visualize(data:Data):void
		{
			// prepare data with default settings and sort
			data.nodes.sortBy("data.controller");
			data.nodes.setProperties({
				shape: Shapes.POLYGON,
				lineColor: 0,
				fillValue: 1,
				fillSaturation: 0.5
			});
			
			var colors:ColorPalette = ColorPalette.category(10);
			var node:NodeSprite;

			var controllerCount = 0;
			var actionCount = 0;
			var currentController = null;
			
			//apply different colors to all of the data points
			for each (node in data.nodes)
			{
				if (currentController != node.data.controller && node.data.action == null)
				{
					node.fillColor = colors.getColorByIndex(controllerCount%10);
					controllerCount++;
					actionCount=0;
					currentController = node.data.controller;
				}
				else {
					node.fillColor = colors.getColorByIndex(actionCount%10);
					actionCount++;
				}
			}
			// define the visualization
			_vis = new Visualization(data);
			// first, set the visibility according to the query
			_vis.operators.add(new VisibilityFilter(filter));
			_vis.operators[0].immediate = true; // filter immediately!
			// second, layout the stacked chart
			_stackedLayout= new StackedAreaLayout(_cols, 0);
			_stackedLayout.normalize = false;
		
			_vis.operators.add(_stackedLayout);
			//_vis.operators[1].scale.labelFormat = "0.####%"; // show as percent
			_vis.operators[1].scale.labelFormat = "#######";
			// third, label the stacks
			_vis.operators.add(new StackedAreaLabeler(this.labeler));
			// fourth, set the color saturation for the current view
			//_vis.operators.add(new SaturationEncoder());
			
			// initialize y-axis labels: align and add mask
			_labelMask = new Shape();
			//_vis.xyAxes.addChild(_labelMask); // hides extreme labels
			_vis.xyAxes.yAxis.labels.mask = _labelMask;
			_vis.xyAxes.yAxis.verticalAnchor = TextSprite.TOP;
			_vis.xyAxes.yAxis.horizontalAnchor = TextSprite.RIGHT;
			_vis.xyAxes.yAxis.labelOffsetX = 50;  // offset labels to the right
			_vis.xyAxes.yAxis.lineCapX1 = 15; // extra line length to the left
			_vis.xyAxes.yAxis.lineCapX2 = 50; // extra line length to the right
			_vis.xyAxes.showBorder = false;
			
			// place and update
			_vis.update();
			addChild(_vis);
						
			// add mouse-over highlight
			_vis.controls.add(new HoverControl(NodeSprite,
			    // move highlighted node to be drawn on top
				HoverControl.MOVE_AND_RETURN,
				// highlight node to full saturation
				function(e:SelectionEvent):void {
					e.node.props.saturation = e.node.fillSaturation;
					e.node.fillSaturation *= 0.5;
				},
				// return node to previous saturation
				function(e:SelectionEvent):void {
					e.node.fillSaturation = e.node.props.saturation;
				}
			));
				
			// add filter on click
			
			_vis.controls.add(new ClickControl(NodeSprite, 1,
				function(e:SelectionEvent):void {
					if(_filteredController == null)
					{
						_filteredController = e.node.data.controller;
					}
					else
					{
						_filteredController = null;
					}
					updateVis();
				}
			));
			
			
			// add tooltips
			_vis.controls.add(new TooltipControl(NodeSprite, null,
			    // update on both roll-over and mouse-move
				updateTooltip, updateTooltip));
			
			// add title and search box
			addControls();
			layout();
		}
		
		private function updateTooltip(e:TooltipEvent):void
		{
		
			var date:String = _vis.xyAxes.xAxis.value(_vis.mouseX, _vis.mouseY).toString();
			var def:Boolean = (e.node.data[date] != undefined);
			var spriteName:String = labeler(e.node);
			
			TextSprite(e.tooltip).htmlText = Strings.format(
				"<b>{0}</b> hits <br/>in {1}: {2}",
				spriteName,
				date, (def ? e.node.data[date] : "Missing Data"));
		
		}
		
		public override function resize(bounds:Rectangle):void
		{
			if (_bar) {
				_bar.x = bounds.width/2 - _bar.width/2;
				_bar.y = bounds.height/2 - _bar.height/2;
			}
			bounds.width -= 100;
			bounds.height -= (50);
			bounds.x += 50;
			bounds.y += 25;
			_bounds = bounds;
			layout();
		}
		
		private function layout():void
		{
			if (_vis) {
				// compute the visualization bounds
				_vis.bounds = _bounds;
				// mask the y-axis labels to hide extreme animation
				_labelMask.graphics.clear();
				_labelMask.graphics.beginFill(0);
				_labelMask.graphics.drawRect(_vis.bounds.right,_vis.bounds.top, 60, 1+_vis.bounds.height);
				// update
				_vis.update();
			}
			if (_toggleLink) {
				var b:Rectangle = getBounds(this);
				_toggleLink.x =  b.right - 50;
				_toggleLink.y = b.top;
			}
			
		}
		private function addControls():void
		{		
			_toggleLink = new TextSprite("View normalized");
			_toggleLink.textFormat = new TextFormat("Verdana",14);
			_toggleLink.horizontalAnchor = TextSprite.RIGHT;
			_toggleLink.addEventListener(MouseEvent.CLICK, function(event:MouseEvent):void {
				toggleAbsoluteMode();
			});
			addChild(_toggleLink);
			
		}
		private function updateVis():void
		{
			_vis.update(1).play();
		}
		
		private function toggleAbsoluteMode():void
		{
			_absoluteMode = !_absoluteMode;
			_stackedLayout.normalize = !_absoluteMode;
			_stackedLayout.scale.labelFormat = _absoluteMode ? "#######" : "0.####%";
			_toggleLink.text = _absoluteMode ? "View normalized" : "View absolute";
			updateVis();
			
		}
		
		/** Filter function for determining visibility. */
		private function filter(d:DataSprite):Boolean
		{
			if (_filteredController == null)
			{
				return (d.data.action == null);
			}
			else
			{
				return (d.data.controller == _filteredController && d.data.action != null);
			}
		
		}
		private function labeler(d:Object):String
		{
			if (d.data.action == null)
			{
				return d.data.controller;
			}
			else{
				return d.data.controller + "/" + d.data.action;
			}
		}
		
		public static function extractColumns(tuples:Array, dim:String):Array
		{
			var cols:Array = new Array();
			// get all distinct values in "dim", then sort them
			var colVals:Object = new Object();
			
			for each (var t:Object in tuples) {
				colVals[t[dim]] = t[dim];
			}
			for each(var dimVal:String in colVals)
			{
				cols.push(dimVal);
			}
			cols.sort();
			return cols;
		}
		// roll up the action level data into a contoller level data
		public static function aggregateData(data: Array, dim:String, colNames: Array): Array
		{
			var aggregates:Object = new Object();
			var currentGroup:Object = null;
			for each (var d:Object in data)
			{
				currentGroup = aggregates[d[dim]];
				if (currentGroup == null)
				{
					currentGroup = new Object();
					currentGroup[dim] = d[dim];
					aggregates[d[dim]] = currentGroup;
					for each (var name:String in colNames){
						currentGroup[name] = d[name];
					}
				}
				else
				{
					for each (var colName:String in colNames){
						currentGroup[colName] += d[colName];
					}
				}
			}
			var aggregateArray:Array = [];
			for each(var val:Object in aggregates)
			{
				aggregateArray.push(val);	
			}
			return aggregateArray;
			
		}
		
		/**
		 * Reshapes a data set, pivoting from rows to columns. For example, if
		 * yearly data is stored in individual rows, this method can be used to
		 * map each year into a column and the full time series into a single
		 * row. This is often needed to use the stacked area layout.
		 * @param tuples an array of data tuples
		 * @param cats the category values to maintain
		 * @param dim the dimension upon which to pivot. The values of this
		 *  property should correspond to the names of newly created columns.
		 * @param measure the numerical value of interest. The values of this
		 *  property will be used as the values of the new columns.
		 * @param cols an ordered array of the new column names. These should
		 *  match the values of the <code>dim</code> property.
		 * @param normalize a flag indicating if the data should be normalized
		 */
		public static function reshape(tuples:Array, cats:Array, dim:String,
			measure:String, cols:Array, normalize:Boolean=true):Array
		{
			var t:Object, d:Object, val:Object, name:String;
			var data:Array = [], names:Array = []
			var totals:Object = {};

			
			for each (val in cols) totals[val] = 0;
			
			// create data set
			for each (t in tuples) {
				// create lookup hash for tuple
				var hash:String = "";
				for each (name in cats) hash += t[name];
				
				if (names[hash] == null) {
					// create a new data tuple
					data.push(d = {});
					for each (name in cats) d[name] = t[name];
					d[t[dim]] = t[measure];
					names[hash] = d;
				} else {
					// update an existing data tuple
					names[hash][t[dim]] = t[measure];
				}
				totals[t[dim]] += t[measure];
			}
			// zero out missing data
			for each (t in data) {
				var max:Number = 0;
				for each (name in cols) {
					if (!t[name]) t[name] = 0; // zero out null entries
					if (normalize)
						t[name] /= totals[name]; // normalize
					if (t[name] > max) max = t[name];
				}
				t.max = max;
			}
			return data;
		}
		
			
	}
}
