local Types = require(script.Parent.Types)

export type BoostItemData = {
	Type: "Boost",
}
export type ModifierItemData = {
	Type: "Modifier",
	Modifier: Types.Modifier,
}

export type ItemMetaData = BoostItemData | ModifierItemData

export type Item = {
	Position: Vector3,
	Id: number,
	Collector: Player?,
	Data: ItemMetaData,
}

return {}
