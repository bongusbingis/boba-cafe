--!strict

export type ItemProperties = {
	[string]: any,
}

export type ItemType = "Nametags" | "Pets"

export type InventoryItemRoot = {
	Name: string,
	Tier: string?,
	Equipped: boolean?,
	StackCount: number?,
	Properties: ItemProperties?,
}

export type InventoryTypeRoot = {
	[string]: InventoryItemRoot,
}

export type InventoryItemsRoot = {
	[ItemType]: InventoryTypeRoot,
}

export type InventoryStore = {
	[string]: InventoryItemsRoot,
}

export type ChangeAction = "added" | "removed" | "updated" | "equipped"

export type OnChangeData = {
	action: ChangeAction,
	itemId: string,
	itemsType: ItemType,
}

return nil
