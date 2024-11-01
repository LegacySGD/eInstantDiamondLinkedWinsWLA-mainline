<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
					<![CDATA[
					var debugFeed = [];
					var debugFlag = false;
					// Format instant win JSON results.
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc)
					{
						var scenario = getScenario(jsonContext);
						var scenarioDataParts = getDataParts(scenario);
						var scenarioTurns = scenarioDataParts.length / 2;
						var convertedPrizeValues = (prizeValues.substring(1)).split('|').map(function(item) {return item.replace(/\t|\r|\n/gm, "")} );
						var prizeNames = (prizeNamesDesc.substring(1)).split(','); 

						////////////////////
						// Parse scenario //
						////////////////////

						// get arrScenarioTurns = array {turns} of objects {arrWinNums: array {items} of objects {iNum: integer, bMatched: boolean},
						//                                                  arrYourNums: array {items} of objects {iNum: integer, bMatched: boolean, strIWMulti: string, strPrize: string, bBonus: boolean}}

						var arrScenarioTurns = [];
						var arrTurnWinNums   = [];
						var arrTurnYourNums  = [];
						var arrYourNumItems  = [];
						var dataPartIndex    = -1;
						var objDataTurn      = {};
						var objWinNum        = {};
						var objYourNum       = {};

						for (var turnIndex = 0; turnIndex < scenarioTurns; turnIndex++)
						{
							objDataTurn   = {arrWinNums: [], arrYourNums: []};
							dataPartIndex = turnIndex * 2;

							arrTurnWinNums = scenarioDataParts[dataPartIndex].split(",").map(function(item) {return parseInt(item,10);} );

							for (var winNumIndex = 0; winNumIndex < arrTurnWinNums.length; winNumIndex++)
							{
								objWinNum = {iNum: 0, bMatched: false};

								objWinNum.iNum = arrTurnWinNums[winNumIndex];

								objDataTurn.arrWinNums.push(objWinNum);
							}

							arrTurnYourNums = scenarioDataParts[dataPartIndex+1].split(",");

							for (var yourNumIndex = 0; yourNumIndex < arrTurnYourNums.length; yourNumIndex++)
							{
								objYourNum = {iNum: 0, bMatched: false, strIWMulti: '', strPrize: '', bBonus: false};

								arrYourNumItems = arrTurnYourNums[yourNumIndex].split(":");
        
								if (arrYourNumItems[0] == 'Z')
								{
									objYourNum.bBonus = true;
								}
								else if (arrYourNumItems[0][0] == 'i')
								{
									objYourNum.strIWMulti = arrYourNumItems[0];
									objYourNum.strPrize   = arrYourNumItems[1];
								}
								else
								{
									objYourNum.iNum     = parseInt(arrYourNumItems[0],10);
									objYourNum.strPrize = arrYourNumItems[1];

									if (arrTurnWinNums.indexOf(objYourNum.iNum) != -1)
									{
										objYourNum.bMatched = true;

										objDataTurn.arrWinNums[arrTurnWinNums.indexOf(objYourNum.iNum)].bMatched = true;
									}
								}
								
								objDataTurn.arrYourNums.push(objYourNum);
							}

							arrScenarioTurns.push(objDataTurn);
						}

						// get arrScenarioClusters = array {turns} of array {clusters} of array {cells} of integers

						const gridCols = 5;
						const gridRows = 4;

						var arrCheckedCells     = [];
						var arrClusterCells     = [];
						var arrScenarioClusters = [];
						var arrTurnClusters     = [];

						function checkNeighbours(A_cellIndex)
						{
							const eDir = {N:1, E:2, S:3, W:4};
							
							var tryCell = -1;
							
							for (var dirIndex = eDir.N; dirIndex <= eDir.W; dirIndex++)
							{
								tryCell = -1;
								
								if (dirIndex == eDir.N && A_cellIndex >= gridCols)                {tryCell = A_cellIndex - gridCols;}
								if (dirIndex == eDir.E && A_cellIndex % gridCols != gridCols-1)   {tryCell = A_cellIndex + 1;}
								if (dirIndex == eDir.S && A_cellIndex <= gridCols * (gridRows-1)) {tryCell = A_cellIndex + gridCols;}
								if (dirIndex == eDir.W && A_cellIndex % gridCols != 0)            {tryCell = A_cellIndex - 1;}
								
								if (tryCell > -1 && tryCell < gridCols * gridRows && arrCheckedCells.indexOf(tryCell) == -1 &&
								    arrScenarioTurns[turnIndex].arrWinNums.map(function(item) {return item.iNum;} ).indexOf(arrScenarioTurns[turnIndex].arrYourNums[tryCell].iNum) != -1)
								{
									arrClusterCells.push(tryCell);
									arrCheckedCells.push(tryCell);
									
									checkNeighbours(tryCell);
								}
							}
						}

						for (var turnIndex = 0; turnIndex < scenarioTurns; turnIndex++)
						{
							arrTurnClusters = [];
							arrCheckedCells = [];
							
							for (var yourNumIndex = 0; yourNumIndex < arrScenarioTurns[turnIndex].arrYourNums.length; yourNumIndex++)
							{
								if (arrScenarioTurns[turnIndex].arrYourNums[yourNumIndex].bBonus)
								{
									arrCheckedCells.push(yourNumIndex);
								}
							}
							
							for (var cellIndex = 0; cellIndex < arrScenarioTurns[turnIndex].arrYourNums.length; cellIndex++)
							{
								arrClusterCells = [];

								if (arrCheckedCells.indexOf(cellIndex) == -1 &&
										(arrScenarioTurns[turnIndex].arrYourNums[cellIndex].strIWMulti != '' ||
											(arrScenarioTurns[turnIndex].arrYourNums[cellIndex].strIWMulti == '' &&
											 arrScenarioTurns[turnIndex].arrWinNums.map(function(item) {return item.iNum;} ).indexOf(arrScenarioTurns[turnIndex].arrYourNums[cellIndex].iNum) != -1)))
								{
									arrClusterCells.push(cellIndex);
									arrCheckedCells.push(cellIndex);
									
									if (arrScenarioTurns[turnIndex].arrYourNums[cellIndex].strIWMulti == '')
									{
										checkNeighbours(cellIndex);
									}
								}
								
								if (arrClusterCells.length > 0)
								{
									arrTurnClusters.push(arrClusterCells);
								}
							}
							
							arrScenarioClusters.push(arrTurnClusters);
						}

						///////////////////////
						// Output Game Parts //
						///////////////////////

						const cellMargin = 1;

						const colourBlack  = '#000000';
						const colourBlue   = '#99ccff';
						const colourLime   = '#ccff99';
						const colourOrange = '#ffcc99';
						const colourWhite  = '#ffffff';
						const colourYellow = '#ffff00';

						var r = [];

						var boxColourStr = '';
						var canvasIdStr  = '';
						var elementStr   = '';

						function showBox(A_strCanvasId, A_strCanvasElement, A_strBoxColour, A_iBoxSize, A_iTextSize, A_strText)
						{
							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;

							r.push('<canvas id="' + A_strCanvasId + '" width="' + (A_iBoxSize + 2 * cellMargin).toString() + '" height="' + (A_iBoxSize + 2 * cellMargin).toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold ' + A_iTextSize.toString() + 'px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (cellMargin + 0.5).toString() + ', ' + (cellMargin + 0.5).toString() + ', ' + A_iBoxSize.toString() + ', ' + A_iBoxSize.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (cellMargin + 1.5).toString() + ', ' + (cellMargin + 1.5).toString() + ', ' + (A_iBoxSize - 2).toString() + ', ' + (A_iBoxSize - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + colourBlack + '";');
							r.push(canvasCtxStr + '.fillText("' + A_strText + '", ' + (A_iBoxSize / 2 + 1).toString() + ', ' + (A_iBoxSize / 2 + 2).toString() + ');');
							r.push('</script>');
						}

						/////////////////
						// Colours Key //
						/////////////////

						const keySymbs = 'MLIB';

						const cellSizeKey = 24;
						const textSizeKey = 14;

						const keyColours = [colourLime, colourBlue, colourOrange, colourYellow];

						var keyStr   = '';
						var keySymb  = '';
						var symbDesc = '';

						r.push('<div style="float:left; margin-right:50px">');
						r.push('<p>' + getTranslationByName("titleColoursKey", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keyColour", translations) + '</td>');
						r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var keyIndex = 0; keyIndex < keySymbs.length; keyIndex++)
						{
							keySymb      = keySymbs[keyIndex];
							canvasIdStr  = 'cvsKeySymb' + keySymb;
							elementStr   = 'eleKeySymb' + keySymb;
							boxColourStr = keyColours[keyIndex];
							keyStr       = (keySymb == 'B') ? 'FP' : '';
							symbDesc     = 'symb' + keySymb;

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showBox(canvasIdStr, elementStr, boxColourStr, cellSizeKey, textSizeKey, keyStr);

							r.push('</td>');
							r.push('<td>' + getTranslationByName(symbDesc, translations) + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						////////////////
						// Game Turns //
						////////////////

						const cellSizeWinNum = 40;
						const textSizeWinNum = 24;

						const IWMultiStr = [{symb: 'i1', multi: 50}, {symb: 'i2', multi: 20}, {symb: 'i3', multi: 10}, {symb: 'i4', multi: 5}, {symb: 'i5', multi: 3}, {symb: 'i6', multi: 2}];

						var arrMulsCluster = [];
						var arrMulsTurn    = [];
						var arrWinsCluster = [];
						var arrWinsTurn    = [];
						var clusterYNIndex = -1;
						var iMultiVal      = 0;
						var isIWMulti      = false;
						var isLinkedWin    = false;
						var objClusterWin  = {};
						var objTurnWin     = {};
						var phaseStr       = '';
						var strMulti       = '';						
						var winNumStr      = '';
						var winPrize       = '';

						function showGrid(A_strCanvasId, A_strCanvasElement, A_arrGrid, A_arrClusters)
						{
							const cellSizeYourNumX = 72;
							const cellSizeYourNumY = 48;
							const cellTextYNum     = 20;
							const cellTextYFP      = 28;
							const cellTextYPrize   = 40;

							var canvasCtxStr     = 'canvasContext' + A_strCanvasElement;
							var cellX            = 0;
							var cellY            = 0;
							var gridCanvasHeight = gridRows * cellSizeYourNumY + 2 * cellMargin;
							var gridCanvasWidth  = gridCols * cellSizeYourNumX + 2 * cellMargin;
							var isBonus          = false;
							var isIWMulti        = false;
							var isLinkedWin      = false;
							var isMatch          = false;
							var linkedCells      = A_arrClusters.filter(function(item) {return item.length > 1;} ).join(",").split(",").map(function(item) {return parseInt(item,10); });
							var prizeStr         = '';
							var yourNumIndex     = -1;
							var yourNumPos       = -1;
							var yourNumPrize     = '';
							var yourNumStr       = '';

							r.push('<canvas id="' + A_strCanvasId + '" width="' + gridCanvasWidth.toString() + '" height="' + gridCanvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');

							for (var gridRow = 0; gridRow < gridRows; gridRow++)							
							{
								for (var gridCol = 0; gridCol < gridCols; gridCol++)
								{
									cellX        = gridCol * cellSizeYourNumX;
									cellY        = gridRow * cellSizeYourNumY;
									yourNumIndex = gridRow * gridCols + gridCol;
									objYourNum   = A_arrGrid[yourNumIndex];
									isMatch      = objYourNum.bMatched;
									isIWMulti    = (objYourNum.strIWMulti != '');
									isBonus      = objYourNum.bBonus;
									isLinkedWin  = (isMatch && linkedCells.indexOf(yourNumIndex) != -1);
									boxColourStr = (isMatch) ? ((isLinkedWin) ? colourBlue : colourLime) : ((isIWMulti) ? colourOrange : ((isBonus) ? colourYellow : colourWhite));
									yourNumStr   = (isIWMulti) ? objYourNum.strIWMulti : ((isBonus) ? 'FP' : objYourNum.iNum.toString());
									yourNumStr   = (isIWMulti) ? IWMultiStr[IWMultiStr.map(function(item) {return item.symb;} ).indexOf(yourNumStr)].multi.toString() + 'x' : yourNumStr;
									yourNumPos   = (isBonus) ? cellTextYFP : cellTextYNum;
									yourNumPrize = objYourNum.strPrize;
									prizeStr     = (yourNumPrize != '') ? convertedPrizeValues[getPrizeNameIndex(prizeNames, yourNumPrize)] : '';

									r.push(canvasCtxStr + '.strokeRect(' + (cellX + cellMargin + 0.5).toString() + ', ' + (cellY + cellMargin + 0.5).toString() + ', ' + cellSizeYourNumX.toString() + ', ' + cellSizeYourNumY.toString() + ');');
									r.push(canvasCtxStr + '.fillStyle = "' + boxColourStr + '";');
									r.push(canvasCtxStr + '.fillRect(' + (cellX + cellMargin + 1.5).toString() + ', ' + (cellY + cellMargin + 1.5).toString() + ', ' + (cellSizeYourNumX - 2).toString() + ', ' + (cellSizeYourNumY - 2).toString() + ');');
									r.push(canvasCtxStr + '.font = "bold 28px Arial";');
									r.push(canvasCtxStr + '.fillStyle = "' + colourBlack + '";');
									r.push(canvasCtxStr + '.fillText("' + yourNumStr + '", ' + (cellX + cellSizeYourNumX / 2 + 1).toString() + ', ' + (cellY + yourNumPos).toString() + ');');
									r.push(canvasCtxStr + '.font = "bold 10px Arial";');
									r.push(canvasCtxStr + '.fillText("' + prizeStr + '", ' + (cellX + cellSizeYourNumX / 2 + 1).toString() + ', ' + (cellY + cellTextYPrize).toString() + ');');
								}
							}

							r.push('</script>');
						}

						function getClusterPrize(A_arrPrizes, A_arrMultis)
						{
							var bCurrSymbAtFront = false;
							var strCurrSymb      = '';
							var strDecSymb       = '';
							var strThouSymb      = '';

							var iPrize         = 0;
							var iTotalPrize    = 0;
							var iTotalSum      = 0;
							var strPrizeAmount = '';

							function getCurrencyInfoFromTopPrize()
							{
								var topPrize                = convertedPrizeValues[0];
								var strPrizeWithoutCurrency = topPrize.replace(new RegExp('[^0-9., ]', 'g'), '');
								var iPos 					= topPrize.indexOf(strPrizeWithoutCurrency);
								var iCurrSymbLength 		= topPrize.length - strPrizeWithoutCurrency.length;
								var strPrizeWithoutDigits   = strPrizeWithoutCurrency.replace(new RegExp('[0-9]', 'g'), '');

								strDecSymb 		 = strPrizeWithoutCurrency.substr(-3,1);									
								bCurrSymbAtFront = (iPos != 0);									
								strCurrSymb 	 = (bCurrSymbAtFront) ? topPrize.substr(0,iCurrSymbLength) : topPrize.substr(-iCurrSymbLength);
								strThouSymb      = (strPrizeWithoutDigits.length > 1) ? strPrizeWithoutDigits[0] : strThouSymb;
							}

							function getPrizeInCents(AA_strPrize)
							{
								return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
							}

							function getCentsInCurr(AA_iPrize)
							{
								var strValue = AA_iPrize.toString();

								strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
								strValue = strValue.substr(0,strValue.length-2) + strDecSymb + strValue.substr(-2);
								strValue = (strValue.length > 6) ? strValue.substr(0,strValue.length-6) + strThouSymb + strValue.substr(-6) : strValue;
								strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

								return strValue;
							}	

							getCurrencyInfoFromTopPrize();

							for (prizeIndex = 0; prizeIndex < A_arrPrizes.length; prizeIndex++)						
							{
								strPrizeAmount = convertedPrizeValues[getPrizeNameIndex(prizeNames, A_arrPrizes[prizeIndex])];
								iPrize         = getPrizeInCents(strPrizeAmount);
								iTotalSum      += iPrize;
								iTotalPrize    += iPrize * A_arrMultis[prizeIndex];
							}

							return {strSum: getCentsInCurr(iTotalSum), strPrize: getCentsInCurr(iTotalPrize)};
						}

						r.push('<p style="clear:both"><br>' + getTranslationByName("gamePhases", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("gamePhase", translations) + '</td>');
						r.push('<td>' + getTranslationByName("winNumbers", translations) + '</td>');
						r.push('<td>' + getTranslationByName("yourNumbers", translations) + '</td>');
						r.push('<td>' + getTranslationByName("prizes", translations) + '</td>');
						r.push('</tr>');

						for (var turnIndex = 0; turnIndex < scenarioTurns; turnIndex++)
						{
							////////////////
							// Phase Info //
							////////////////

							phaseStr = (turnIndex == 0) ? getTranslationByName("mainGame", translations) : getTranslationByName("freePlay", translations) + ' ' + turnIndex.toString() ;

							r.push('<tr class="tablebody">');
							r.push('<td valign="top" style="padding-right:50px">' + phaseStr + '</td>');

							/////////////////
							// Win Numbers //
							/////////////////

							r.push('<td valign="top" style="padding-right:50px">');
							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablebody">');

							for (var winNumIndex = 0; winNumIndex < arrScenarioTurns[turnIndex].arrWinNums.length; winNumIndex++)
							{
								canvasIdStr  = 'cvsWinNum' + turnIndex.toString() + '_' + winNumIndex.toString();
								elementStr   = 'eleWinNum' + turnIndex.toString() + '_' + winNumIndex.toString();
								boxColourStr = (arrScenarioTurns[turnIndex].arrWinNums[winNumIndex].bMatched) ? colourLime : colourWhite;
								winNumStr    = arrScenarioTurns[turnIndex].arrWinNums[winNumIndex].iNum.toString();

								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, boxColourStr, cellSizeWinNum, textSizeWinNum, winNumStr);

								r.push('</td>');
							}

							r.push('</tr>');
							r.push('</table>');
							r.push('</td>');

							///////////////////////
							// Your Numbers Grid //
							///////////////////////

							canvasIdStr = 'cvsYourNums' + turnIndex.toString();
							elementStr  = 'eleYourNums' + turnIndex.toString();

							r.push('<td valign="top" style="padding-right:50px; padding-bottom:25px">');

							showGrid(canvasIdStr, elementStr, arrScenarioTurns[turnIndex].arrYourNums, arrScenarioClusters[turnIndex]);

							r.push('</td>');

							////////////
							// Prizes //
							////////////

							arrWinsTurn = [];
							arrMulsTurn = [];

							r.push('<td valign="top" style="padding-bottom:25px">');

							if (arrScenarioClusters[turnIndex].length > 0)
							{
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

								for (var clusterIndex = 0; clusterIndex < arrScenarioClusters[turnIndex].length; clusterIndex++)
								{
									arrWinsCluster = [];
									arrMulsCluster = [];
									clusterYNIndex = arrScenarioClusters[turnIndex][clusterIndex][0];
									strMulti       = arrScenarioTurns[turnIndex].arrYourNums[clusterYNIndex].strIWMulti;
									isIWMulti      = (strMulti != '');
									iMultiVal      = (isIWMulti) ? IWMultiStr[IWMultiStr.map(function(item) {return item.symb;} ).indexOf(strMulti)].multi : arrScenarioClusters[turnIndex][clusterIndex].length; 

									for (cellIndex = 0; cellIndex < arrScenarioClusters[turnIndex][clusterIndex].length; cellIndex++)
									{
										clusterYNIndex = arrScenarioClusters[turnIndex][clusterIndex][cellIndex];
										winPrize       = arrScenarioTurns[turnIndex].arrYourNums[clusterYNIndex].strPrize;

										arrWinsCluster.push(winPrize);
										arrMulsCluster.push(iMultiVal);
										arrWinsTurn.push(winPrize);
										arrMulsTurn.push(iMultiVal);
									}

									canvasIdStr   = 'cvsPrize' + turnIndex.toString() + '_' + clusterIndex.toString();
									elementStr    = 'elePrize' + turnIndex.toString() + '_' + clusterIndex.toString();
									boxColourStr  = (isIWMulti) ? colourOrange : ((iMultiVal > 1) ? colourBlue : colourLime);
									objClusterWin = getClusterPrize(arrWinsCluster,arrMulsCluster);

									r.push('<tr class="tablebody">');
									r.push('<td align="right">' + objClusterWin.strSum + ' x</td>');
									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, boxColourStr, cellSizeKey, textSizeKey, iMultiVal.toString());

									r.push('</td>');
									r.push('<td>=</td><td align="right">' + objClusterWin.strPrize + '</td>');
									r.push('</tr>');
								}

								objTurnWin = getClusterPrize(arrWinsTurn,arrMulsTurn);

								r.push('<tr class="tablebody">');
								r.push('<td colspan="4">&nbsp;</td>');
								r.push('</tr>');
								r.push('<tr class="tablebody">');
								r.push('<td colspan="2" align="right">' + getTranslationByName("total", translations) + '</td>');
								r.push('<td>=</td><td align="right">' + objTurnWin.strPrize + '</td>');
								r.push('</tr>');

								r.push('</table>');
							}

							r.push('</td>');
							r.push('</tr>');
						}

						r.push('</table>');

						r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// !DEBUG OUTPUT TABLE
						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						if(debugFlag)
						{
							//////////////////////////////////////
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" width="100%" class="gameDetailsTable" style="table-layout:fixed">');
							for(var idx = 0; idx < debugFeed.length; ++idx)
 							{
								if(debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
	 							r.push('</tr>');
							}
							r.push('</table>');
						}
						return r.join('');
					}

					function getScenario(jsonContext)
					{
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}

					function getDataParts(scenario)
					{
						return scenario.split("|"); 
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");

						for(var i = 0; i < pricePoints.length; ++i)
						{
							if(wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}

						return "";
					}

					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;

						return pricePoint;
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for (var i = 0; i < prizeNames.length; ++i)
						{
							if (prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}

					/////////////////////////////////////////////////////////////////////////////////////////
					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if(childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
					]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			
				
				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>

				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
					<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
