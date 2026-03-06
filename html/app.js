const InventoryContainer = Vue.createApp({
  data() {
    return this.getInitialState()
  },
  computed: {
    playerWeight() {
      const weight = Object.values(this.playerInventory).reduce(
        (total, item) => {
          if (item && item.weight !== undefined && item.amount !== undefined) {
            return total + item.weight * item.amount
          }
          return total
        },
        0
      )
      return isNaN(weight) ? 0 : weight
    },
    otherInventoryWeight() {
      const weight = Object.values(this.otherInventory).reduce(
        (total, item) => {
          if (item && item.weight !== undefined && item.amount !== undefined) {
            return total + item.weight * item.amount
          }
          return total
        },
        0
      )
      return isNaN(weight) ? 0 : weight
    },
    weightBarClass() {
      const weightPercentage = (this.playerWeight / this.maxWeight) * 100
      if (weightPercentage < 50) {
        return 'low'
      } else if (weightPercentage < 75) {
        return 'medium'
      } else {
        return 'high'
      }
    },
    otherWeightBarClass() {
      const weightPercentage =
        (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100
      if (weightPercentage < 50) {
        return 'low'
      } else if (weightPercentage < 75) {
        return 'medium'
      } else {
        return 'high'
      }
    },
    shouldCenterInventory() {
      return this.isOtherInventoryEmpty
    }
  },
  watch: {
    transferAmount(newVal) {
      if (newVal !== null && newVal < 1) this.transferAmount = 1
    }
  },
  methods: {
    // ---------- General UI ----------
    toggleSubmenu(submenu) {
      // Toggle submenu: closes if already open, otherwise opens
      this.activeSubmenu = this.activeSubmenu === submenu ? null : submenu
    },

    // ---------- Initial State ----------
    getInitialState() {
      return {
        // Config
        maxWeight: 0,
        totalSlots: 0,

        // Visibility
        isInventoryOpen: false,
        isOtherInventoryEmpty: true,

        // Error highlight
        errorSlot: null,

        // Player inventory
        playerInventory: {},
        // Header label shown above the player inventory
        playerName: 'Inventory',
        inventoryLabel: 'Inventory',
        totalWeight: 0,

        // Other inventory
        otherInventory: {},
        otherInventoryName: '',
        otherInventoryLabel: 'Drop',
        otherInventoryMaxWeight: 1000000,
        otherInventorySlots: 100,
        isShopInventory: false,

        // Origin info
        inventory: '',

        // Context menu
        showContextMenu: false,
        contextMenuPosition: { top: '0px', left: '0px' },
        contextMenuItem: null,
        activeSubmenu: null, // 'give', 'drop', or null

        // Hotbar
        showHotbar: false,
        hotbarItems: [],

        // Notifications
        showNotification: false,
        notificationText: '',
        notificationImage: '',
        notificationType: 'added',
        notificationAmount: 1,

        // Required items
        showRequiredItems: false,
        requiredItems: [],

        // Weapon attachments
        selectedWeapon: null,
        selectedWeaponSlot: null,
        showWeaponAttachments: false,
        selectedWeaponAttachments: [],
        attachmentsBusy: false,
        attachmentsReqId: 0,

        // Drag & Drop
        currentlyDraggingItem: null,
        currentlyDraggingSlot: null,
        dragStartX: 0,
        dragStartY: 0,
        ghostElement: null,
        dragStartInventoryType: 'player',
        transferAmount: null
      }
    },

    // ---------- Open / Update / Close inventory ----------
    openInventory(data) {
      if (this.showHotbar) {
        this.toggleHotbar(false)
      }

      this.isInventoryOpen = true
      this.playerName = (data && (data.playerName || data.playername || data.name)) || this.inventoryLabel
      this.maxWeight = data.maxweight
      this.totalSlots = data.slots
      this.playerInventory = {}
      this.otherInventory = {}

      if (data.inventory) {
        if (Array.isArray(data.inventory)) {
          data.inventory.forEach((item) => {
            if (item && item.slot) {
              this.playerInventory[item.slot] = item
            }
          })
        } else if (typeof data.inventory === 'object') {
          for (const key in data.inventory) {
            const item = data.inventory[key]
            if (item && item.slot) {
              this.playerInventory[item.slot] = item
            }
          }
        }
      }

      if (data.other) {
        if (data.other && data.other.inventory) {
          if (Array.isArray(data.other.inventory)) {
            data.other.inventory.forEach((item) => {
              if (item && item.slot) {
                this.otherInventory[item.slot] = item
              }
            })
          } else if (typeof data.other.inventory === 'object') {
            for (const key in data.other.inventory) {
              const item = data.other.inventory[key]
              if (item && item.slot) {
                this.otherInventory[item.slot] = item
              }
            }
          }
        }

        this.otherInventoryName = data.other.name
        this.otherInventoryLabel = data.other.label
        this.otherInventoryMaxWeight = data.other.maxweight
        this.otherInventorySlots = data.other.slots

        this.isShopInventory = this.otherInventoryName.startsWith('shop-')
        this.isOtherInventoryEmpty = false
      }
    },

    updateInventory(data) {
      this.playerInventory = {}

      if (data.inventory) {
        if (Array.isArray(data.inventory)) {
          data.inventory.forEach((item) => {
            if (item && item.slot) {
              this.playerInventory[item.slot] = item
            }
          })
        } else if (typeof data.inventory === 'object') {
          for (const key in data.inventory) {
            const item = data.inventory[key]
            if (item && item.slot) {
              this.playerInventory[item.slot] = item
            }
          }
        }
      }

      // Keep drawer weapon reference fresh if open
      if (this.showWeaponAttachments && this.selectedWeaponSlot) {
        this.selectedWeapon =
          this.playerInventory[this.selectedWeaponSlot] || this.selectedWeapon
      }
    },

    async closeInventory() {
      this.clearDragData()
      let inventoryName = this.otherInventoryName
      Object.assign(this, this.getInitialState())
      try {
        await axios.post('https://qb-inventory/CloseInventory', {
          name: inventoryName
        })
      } catch (error) {
        console.error('Error closing inventory:', error)
      }
    },

    // ---------- Utilities ----------
    clearTransferAmount() {
      this.transferAmount = null
    },
    getItemInSlot(slot, inventoryType) {
      if (inventoryType === 'player') {
        return this.playerInventory[slot] || null
      } else if (inventoryType === 'other') {
        return this.otherInventory[slot] || null
      }
      return null
    },
    getHotbarItemInSlot(slot) {
      return this.hotbarItems[slot - 1] || null
    },
    containerMouseDownAction(event) {
      if (event.button === 0 && this.showContextMenu) {
        this.showContextMenu = false
      }
    },

    // ---------- Mouse handlers ----------
    handleMouseDown(event, slot, inventory) {
      if (event.button === 1) return // ignore middle mouse
      event.preventDefault()
      const itemInSlot = this.getItemInSlot(slot, inventory)
      if (event.button === 0) {
        if (event.shiftKey && itemInSlot) {
          this.splitAndPlaceItem(itemInSlot, inventory)
        } else {
          this.startDrag(event, slot, inventory)
        }
      } else if (event.button === 2 && itemInSlot) {
        if (this.otherInventoryName.startsWith('shop-')) {
          this.handlePurchase(slot, itemInSlot.slot, itemInSlot, 1)
          return
        }
        if (!this.isOtherInventoryEmpty) {
          this.moveItemBetweenInventories(itemInSlot, inventory)
        } else {
          this.showContextMenuOptions(event, itemInSlot)
        }
      }
    },

    moveItemBetweenInventories(item, sourceInventoryType) {
      const sourceInventory =
        sourceInventoryType === 'player'
          ? this.playerInventory
          : this.otherInventory
      const targetInventory =
        sourceInventoryType === 'player'
          ? this.otherInventory
          : this.playerInventory
      const amountToTransfer =
        this.transferAmount !== null ? this.transferAmount : 1
      let targetSlot = null

      const sourceItem = sourceInventory[item.slot]
      if (!sourceItem || sourceItem.amount < amountToTransfer) {
        this.inventoryError(item.slot)
        return
      }

      const totalWeightAfterTransfer =
        this.otherInventoryWeight + sourceItem.weight * amountToTransfer
      if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
        this.inventoryError(item.slot)
        return
      }

      if (item.unique) {
        targetSlot = this.findNextAvailableSlot(targetInventory)
        if (targetSlot === null) {
          this.inventoryError(item.slot)
          return
        }

        const newItem = {
          ...item,
          inventory: sourceInventoryType === 'player' ? 'other' : 'player',
          amount: amountToTransfer
        }
        targetInventory[targetSlot] = newItem
        newItem.slot = targetSlot
      } else {
        const targetItemKey = Object.keys(targetInventory).find(
          (key) =>
            targetInventory[key] && targetInventory[key].name === item.name
        )
        const targetItem = targetInventory[targetItemKey]

        if (!targetItem) {
          const newItem = {
            ...item,
            inventory: sourceInventoryType === 'player' ? 'other' : 'player',
            amount: amountToTransfer
          }

          targetSlot = this.findNextAvailableSlot(targetInventory)
          if (targetSlot === null) {
            this.inventoryError(item.slot)
            return
          }

          targetInventory[targetSlot] = newItem
          newItem.slot = targetSlot
        } else {
          targetItem.amount += amountToTransfer
          targetSlot = targetItem.slot
        }
      }

      sourceItem.amount -= amountToTransfer

      if (sourceItem.amount <= 0) {
        delete sourceInventory[item.slot]
      }

      this.postInventoryData(
        sourceInventoryType,
        sourceInventoryType === 'player' ? 'other' : 'player',
        item.slot,
        targetSlot,
        sourceItem.amount,
        amountToTransfer
      )
    },

    // ---------- Drag & Drop core ----------
    startDrag(event, slot, inventoryType) {
      event.preventDefault()
      const item = this.getItemInSlot(slot, inventoryType)
      if (!item) return
      const slotElement = event.target.closest('.item-slot')
      if (!slotElement) return
      const ghostElement = this.createGhostElement(slotElement)
      document.body.appendChild(ghostElement)
      const offsetX = ghostElement.offsetWidth / 2
      const offsetY = ghostElement.offsetHeight / 2
      ghostElement.style.left = `${event.clientX - offsetX}px`
      ghostElement.style.top = `${event.clientY - offsetY}px`
      this.ghostElement = ghostElement
      this.currentlyDraggingItem = item
      this.currentlyDraggingSlot = slot
      this.dragStartX = event.clientX
      this.dragStartY = event.clientY
      this.dragStartInventoryType = inventoryType
      this.showContextMenu = false
      document.body.classList.add('grabbing')
      window.addEventListener('mousemove', this.drag)
      window.addEventListener('mouseup', this.endDrag)
    },
    createGhostElement(slotElement) {
      const ghostElement = slotElement.cloneNode(true)
      ghostElement.style.position = 'absolute'
      ghostElement.style.pointerEvents = 'none'
      ghostElement.style.opacity = '0.7'
      ghostElement.style.zIndex = '1000'
      ghostElement.style.width = getComputedStyle(slotElement).width
      ghostElement.style.height = getComputedStyle(slotElement).height
      ghostElement.style.boxSizing = 'border-box'
      return ghostElement
    },
    drag(event) {
      if (!this.currentlyDraggingItem || !this.ghostElement) return
      const centeredX = event.clientX - this.ghostElement.offsetWidth / 2
      const centeredY = event.clientY - this.ghostElement.offsetHeight / 2
      this.ghostElement.style.left = `${centeredX}px`
      this.ghostElement.style.top = `${centeredY}px`
    },
    endDrag(event) {
      if (!this.currentlyDraggingItem) return
      const targetPlayerItemSlotElement = event.target.closest(
        '.player-inventory .item-slot'
      )
      if (targetPlayerItemSlotElement) {
        const targetSlot = Number(targetPlayerItemSlotElement.dataset.slot)
        if (
          targetSlot &&
          !(
            targetSlot === this.currentlyDraggingSlot &&
            this.dragStartInventoryType === 'player'
          )
        ) {
          this.handleDropOnPlayerSlot(targetSlot)
        }
      }
      const targetOtherItemSlotElement = event.target.closest(
        '.other-inventory .item-slot'
      )
      if (targetOtherItemSlotElement) {
        const targetSlot = Number(targetOtherItemSlotElement.dataset.slot)
        if (
          targetSlot &&
          !(
            targetSlot === this.currentlyDraggingSlot &&
            this.dragStartInventoryType === 'other'
          )
        ) {
          this.handleDropOnOtherSlot(targetSlot)
        }
      }
      const targetInventoryContainer = event.target.closest('#app')
      if (
        targetInventoryContainer &&
        !targetPlayerItemSlotElement &&
        !targetOtherItemSlotElement
      ) {
        this.handleDropOnInventoryContainer()
      }
      this.clearDragData()
      document.body.classList.remove('grabbing')
      window.removeEventListener('mousemove', this.drag)
      window.removeEventListener('mouseup', this.endDrag)
    },
    handleDropOnPlayerSlot(targetSlot) {
      if (this.isShopInventory && this.dragStartInventoryType === 'other') {
        const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } =
          this
        const targetInventory = this.getInventoryByType('player')
        const targetItem = targetInventory[targetSlot]
        if (
          (targetItem && targetItem.name !== currentlyDraggingItem.name) ||
          (targetItem &&
            targetItem.name === currentlyDraggingItem.name &&
            currentlyDraggingItem.unique)
        ) {
          this.inventoryError(currentlyDraggingSlot)
          return
        }
        this.handlePurchase(
          targetSlot,
          currentlyDraggingSlot,
          currentlyDraggingItem,
          transferAmount
        )
      } else {
        this.handleItemDrop('player', targetSlot)
      }
    },
    handleDropOnOtherSlot(targetSlot) {
      this.handleItemDrop('other', targetSlot)
    },
    async handleDropOnInventoryContainer() {
      if (
        this.isOtherInventoryEmpty &&
        this.dragStartInventoryType === 'player'
      ) {
        const newItem = {
          ...this.currentlyDraggingItem,
          amount: this.currentlyDraggingItem.amount,
          slot: 1,
          inventory: 'other'
        }
        const draggingItem = this.currentlyDraggingItem
        try {
          const response = await axios.post('https://qb-inventory/DropItem', {
            ...newItem,
            fromSlot: this.currentlyDraggingSlot
          })

          if (response.data) {
            this.otherInventory[1] = newItem
            const draggingItemKey = Object.keys(this.playerInventory).find(
              (key) => this.playerInventory[key] === draggingItem
            )
            if (draggingItemKey) {
              delete this.playerInventory[draggingItemKey]
            }
            this.otherInventoryName = response.data
            this.otherInventoryLabel = response.data
            this.isOtherInventoryEmpty = false
            this.clearDragData()
          }
        } catch (error) {
          this.inventoryError(this.currentlyDraggingSlot)
        }
      }
      this.clearDragData()
    },
    clearDragData() {
      if (this.ghostElement) {
        document.body.removeChild(this.ghostElement)
        this.ghostElement = null
      }
      this.currentlyDraggingItem = null
      this.currentlyDraggingSlot = null
    },
    getInventoryByType(inventoryType) {
      return inventoryType === 'player'
        ? this.playerInventory
        : this.otherInventory
    },

    // ---------- Drop logic ----------
    handleItemDrop(targetInventoryType, targetSlot) {
      try {
        const isShop = this.otherInventoryName.indexOf('shop-')
        if (
          this.dragStartInventoryType === 'other' &&
          targetInventoryType === 'other' &&
          isShop !== -1
        ) {
          return
        }

        const targetSlotNumber = parseInt(targetSlot, 10)
        if (isNaN(targetSlotNumber)) {
          throw new Error('Invalid target slot number')
        }

        const sourceInventory = this.getInventoryByType(
          this.dragStartInventoryType
        )
        const targetInventory = this.getInventoryByType(targetInventoryType)

        const sourceItem = sourceInventory[this.currentlyDraggingSlot]
        if (!sourceItem) {
          throw new Error('No item in the source slot to transfer')
        }

        const amountToTransfer =
          this.transferAmount !== null ? this.transferAmount : sourceItem.amount
        if (sourceItem.amount < amountToTransfer) {
          throw new Error('Insufficient amount of item in source inventory')
        }

        if (targetInventoryType !== this.dragStartInventoryType) {
          if (targetInventoryType == 'other') {
            const totalWeightAfterTransfer =
              this.otherInventoryWeight + sourceItem.weight * amountToTransfer
            if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
              throw new Error(
                'Insufficient weight capacity in target inventory'
              )
            }
          } else if (targetInventoryType == 'player') {
            const totalWeightAfterTransfer =
              this.playerWeight + sourceItem.weight * amountToTransfer
            if (totalWeightAfterTransfer > this.maxWeight) {
              throw new Error(
                'Insufficient weight capacity in player inventory'
              )
            }
          }
        }

        const targetItem = targetInventory[targetSlotNumber]

        if (targetItem) {
          if (sourceItem.name === targetItem.name && targetItem.unique) {
            this.inventoryError(this.currentlyDraggingSlot)
            return
          }
          if (sourceItem.name === targetItem.name && !targetItem.unique) {
            targetItem.amount += amountToTransfer
            sourceItem.amount -= amountToTransfer
            if (sourceItem.amount <= 0) {
              delete sourceInventory[this.currentlyDraggingSlot]
            }
            this.postInventoryData(
              this.dragStartInventoryType,
              targetInventoryType,
              this.currentlyDraggingSlot,
              targetSlotNumber,
              sourceItem.amount,
              amountToTransfer
            )
          } else {
            sourceInventory[this.currentlyDraggingSlot] = targetItem
            targetInventory[targetSlotNumber] = sourceItem
            sourceInventory[this.currentlyDraggingSlot].slot =
              this.currentlyDraggingSlot
            targetInventory[targetSlotNumber].slot = targetSlotNumber
            this.postInventoryData(
              this.dragStartInventoryType,
              targetInventoryType,
              this.currentlyDraggingSlot,
              targetSlotNumber,
              sourceItem.amount,
              targetItem.amount
            )
          }
        } else {
          sourceItem.amount -= amountToTransfer
          if (sourceItem.amount <= 0) {
            delete sourceInventory[this.currentlyDraggingSlot]
          }
          targetInventory[targetSlotNumber] = {
            ...sourceItem,
            amount: amountToTransfer,
            slot: targetSlotNumber
          }
          this.postInventoryData(
            this.dragStartInventoryType,
            targetInventoryType,
            this.currentlyDraggingSlot,
            targetSlotNumber,
            sourceItem.amount,
            amountToTransfer
          )
        }
      } catch (error) {
        console.error(error.message)
        this.inventoryError(this.currentlyDraggingSlot)
      } finally {
        this.clearDragData()
      }
    },

    // ---------- Shop purchase ----------
    async handlePurchase(targetSlot, sourceSlot, sourceItem, transferAmount) {
      try {
        const response = await axios.post(
          'https://qb-inventory/AttemptPurchase',
          {
            item: sourceItem,
            amount: transferAmount || sourceItem.amount,
            shop: this.otherInventoryName
          }
        )
        if (response.data) {
          const sourceInventory = this.getInventoryByType('other')
          const targetInventory = this.getInventoryByType('player')
          const amountToTransfer =
            transferAmount !== null ? transferAmount : sourceItem.amount
          if (sourceItem.amount < amountToTransfer) {
            this.inventoryError(sourceSlot)
            return
          }
          let targetItem = targetInventory[targetSlot]
          if (!targetItem || targetItem.name !== sourceItem.name) {
            let foundSlot = Object.keys(targetInventory).find(
              (slot) =>
                targetInventory[slot] &&
                targetInventory[slot].name === sourceItem.name
            )
            if (foundSlot) {
              targetInventory[foundSlot].amount += amountToTransfer
            } else {
              const targetInventoryKeys = Object.keys(targetInventory)
              if (targetInventoryKeys.length < this.totalSlots) {
                let freeSlot = Array.from(
                  { length: this.totalSlots },
                  (_, i) => i + 1
                ).find((i) => !(i in targetInventory))
                targetInventory[freeSlot] = {
                  ...sourceItem,
                  amount: amountToTransfer
                }
              } else {
                this.inventoryError(sourceSlot)
                return
              }
            }
          } else {
            targetItem.amount += amountToTransfer
          }
          sourceItem.amount -= amountToTransfer
          if (sourceItem.amount <= 0) {
            delete sourceInventory[sourceSlot]
          }
        } else {
          this.inventoryError(sourceSlot)
        }
      } catch (error) {
        this.inventoryError(sourceSlot)
      }
    },

    // ---------- Context actions ----------
    async dropItem(item, quantity) {
      if (item && item.name) {
        const playerItemKey = Object.keys(this.playerInventory).find(
          (key) =>
            this.playerInventory[key] &&
            this.playerInventory[key].slot === item.slot
        )
        if (playerItemKey) {
          let amountToGive

          if (typeof quantity === 'string') {
            switch (quantity) {
              case 'half':
                amountToGive = Math.ceil(item.amount / 2)
                break
              case 'all':
                amountToGive = item.amount
                break
              default:
                console.error('Invalid quantity specified.')
                return
            }
          } else if (typeof quantity === 'number' && quantity > 0) {
            amountToGive = quantity
          } else {
            console.error('Invalid quantity type specified.')
            return
          }

          if (amountToGive > item.amount) {
            amountToGive = item.amount
          }

          const newItem = {
            ...item,
            amount: amountToGive,
            slot: 1,
            inventory: 'other'
          }

          try {
            const response = await axios.post('https://qb-inventory/DropItem', {
              ...newItem,
              fromSlot: item.slot
            })

            if (response.data) {
              delete this.playerInventory[playerItemKey]
              this.otherInventory[1] = newItem
              this.otherInventoryName = response.data
              this.otherInventoryLabel = response.data
              this.isOtherInventoryEmpty = false
            }
          } catch (error) {
            this.inventoryError(item.slot)
          }
        }
      }
      this.showContextMenu = false
    },
    async useItem(item) {
      if (!item || item.useable === false) {
        return
      }
      const playerItemKey = Object.keys(this.playerInventory).find(
        (key) =>
          this.playerInventory[key] &&
          this.playerInventory[key].slot === item.slot
      )
      if (playerItemKey) {
        try {
          await axios.post('https://qb-inventory/UseItem', {
            inventory: 'player',
            item: item
          })
          if (item.shouldClose) {
            this.closeInventory()
          }
        } catch (error) {
          console.error('Error using the item: ', error)
        }
      }
      this.showContextMenu = false
    },
    showContextMenuOptions(event, item) {
      event.preventDefault()
      const menuWidth = 240
      const menuHeight = 200
      const windowWidth = window.innerWidth
      const windowHeight = window.innerHeight

      let menuLeft = event.clientX
      let menuTop = event.clientY

      // keep menu inside viewport
      if (menuLeft + menuWidth > windowWidth) {
        menuLeft = windowWidth - menuWidth - 10
      }
      if (menuTop + menuHeight > windowHeight) {
        menuTop = windowHeight - menuHeight - 10
      }

      this.showContextMenu = true
      this.contextMenuPosition = {
        top: `${menuTop}px`,
        left: `${menuLeft}px`
      }
      this.contextMenuItem = item
    },

    async giveItem(item, quantity) {
      if (item && item.name) {
        const selectedItem = item
        const playerHasItem = Object.values(this.playerInventory).some(
          (invItem) => invItem && invItem.name === selectedItem.name
        )

        if (playerHasItem) {
          let amountToGive
          if (typeof quantity === 'string') {
            switch (quantity) {
              case 'half':
                amountToGive = Math.ceil(selectedItem.amount / 2)
                break
              case 'all':
                amountToGive = selectedItem.amount
                break
              default:
                console.error('Invalid quantity specified.')
                return
            }
          } else {
            amountToGive = quantity
          }

          if (amountToGive > selectedItem.amount) {
            console.error('Specified quantity exceeds available amount.')
            return
          }

          try {
            const response = await axios.post('https://qb-inventory/GiveItem', {
              item: selectedItem,
              amount: amountToGive,
              slot: selectedItem.slot,
              info: selectedItem.info
            })
            if (!response.data) return

            this.playerInventory[selectedItem.slot].amount -= amountToGive
            if (this.playerInventory[selectedItem.slot].amount === 0) {
              delete this.playerInventory[selectedItem.slot]
            }
          } catch (error) {
            console.error('An error occurred while giving the item:', error)
          }
        } else {
          console.error('Player does not have the item in their inventory.')
        }
      }
      this.showContextMenu = false
    },

    // ---------- Slots ----------
    findNextAvailableSlot(inventory) {
      for (let slot = 1; slot <= this.totalSlots; slot++) {
        if (!inventory[slot]) {
          return slot
        }
      }
      return null
    },

    splitAndPlaceItem(item, inventoryType) {
      const inventoryRef =
        inventoryType === 'player' ? this.playerInventory : this.otherInventory
      if (item && item.amount > 1) {
        const originalSlot = Object.keys(inventoryRef).find(
          (key) => inventoryRef[key] === item
        )
        if (originalSlot !== undefined) {
          const newItem = { ...item, amount: Math.ceil(item.amount / 2) }
          const nextSlot = this.findNextAvailableSlot(inventoryRef)
          if (nextSlot !== null) {
            inventoryRef[nextSlot] = newItem
            inventoryRef[originalSlot] = {
              ...item,
              amount: Math.floor(item.amount / 2)
            }
            this.postInventoryData(
              inventoryType,
              inventoryType,
              originalSlot,
              nextSlot,
              item.amount,
              newItem.amount
            )
          }
        }
      }
      this.showContextMenu = false
    },

    // ---------- Hotbar ----------
    toggleHotbar(data) {
      if (data.open) {
        this.hotbarItems = data.items
        this.showHotbar = true
      } else {
        this.showHotbar = false
        this.hotbarItems = []
      }
    },

    // ---------- Notifications / Required Items ----------
    showItemNotification(itemData) {
      this.notificationText = itemData.item.label
      this.notificationImage = 'images/' + itemData.item.image
      this.notificationType =
        itemData.type === 'add'
          ? 'Received'
          : itemData.type === 'use'
          ? 'Used'
          : 'Removed'
      this.notificationAmount = itemData.amount || 1
      this.showNotification = true
      setTimeout(() => {
        this.showNotification = false
      }, 5000)
    },
    showRequiredItem(data) {
      if (data.toggle) {
        this.requiredItems = data.items
        this.showRequiredItems = true
      } else {
        setTimeout(() => {
          this.showRequiredItems = false
          this.requiredItems = []
        }, 100)
      }
    },

    // ---------- Error feedback ----------
    inventoryError(slot) {
      const slotElement = document.getElementById(`slot-${slot}`)
      if (slotElement) {
        slotElement.style.backgroundColor = 'red'
      }
      axios.post('https://qb-inventory/PlayDropFail', {}).catch((error) => {
        console.error('Error playing drop fail:', error)
      })
      setTimeout(() => {
        if (slotElement) {
          slotElement.style.backgroundColor = ''
        }
      }, 1000)
    },

    // ---------- Misc ----------
    copySerial() {
      if (!this.contextMenuItem) return
      const item = this.contextMenuItem
      if (item) {
        const el = document.createElement('textarea')
        el.value = item.info.serie
        document.body.appendChild(el)
        el.select()
        document.execCommand('copy')
        document.body.removeChild(el)
      }
    },

    // ---------- ATTACHMENTS (robust) ----------
    _attKey(a) {
      return (
        (a && (a.component || a.name || a.attachment || a.key || a.hash || a.id)) ||
        null
      )
    },
    _normAtt(listOrObj) {
      const arr = Array.isArray(listOrObj)
        ? listOrObj
        : listOrObj && typeof listOrObj === 'object'
          ? Object.keys(listOrObj).map((k) => ({ __srcKey: k, ...(listOrObj[k] || {}) }))
          : []

      const out = []
      const seen = new Set()
      for (let i = 0; i < arr.length; i++) {
        const raw = arr[i]
        if (!raw || typeof raw !== 'object') continue
        const base = this._attKey(raw) || raw.__srcKey || `idx-${i}`
        let k = String(base), n = 1
        while (seen.has(k)) k = `${base}-${n++}`
        seen.add(k)
        out.push({ ...raw, __k: k }) // __k is ONLY for Vue keys
      }
      return out
    },
    _readLocalAtt(item) {
      return this._normAtt(item?.info?.attachments)
    },
    _writeAttToInventory(slot, attList) {
      if (!slot || !this.playerInventory?.[slot]) return
      const obj = {}
      ;(attList || []).forEach((a) => {
        const k = a?.__k || this._attKey(a)
        if (k) obj[k] = { ...a }
      })
      const item = { ...this.playerInventory[slot] }
      item.info = { ...(item.info || {}), attachments: obj }
      this.playerInventory[slot] = item
      this.selectedWeapon = item
      this.contextMenuItem = item
    },

    async openWeaponAttachments() {
      // Toggle
      if (this.showWeaponAttachments) {
        this.closeWeaponAttachments()
        return
      }
      if (!this.contextMenuItem) return

      // Find fresh weapon by slot or by name
      let slot = this.contextMenuItem.slot || null
      let fresh = slot && this.playerInventory[slot] ? this.playerInventory[slot] : null
      if (!fresh) {
        const k = Object.keys(this.playerInventory || {}).find((s) => {
          const it = this.playerInventory[s]
          return it && it.name === this.contextMenuItem.name
        })
        if (k) { slot = Number(k); fresh = this.playerInventory[k] }
      }
      if (!fresh) fresh = this.contextMenuItem

      this.selectedWeapon = { ...fresh }
      this.selectedWeaponSlot = slot || this.selectedWeapon.slot || null
      this.showWeaponAttachments = true

      // Always paint local as base
      const local = this._readLocalAtt(this.selectedWeapon)
      this.selectedWeaponAttachments = local

      // Ask server; only override if it returns > 0
      try {
        const res = await axios.post('https://qb-inventory/GetWeaponData', {
          weapon: this.selectedWeapon.name,
          ItemData: this.selectedWeapon
        })
        const data = res?.data || {}
        const serverList = this._normAtt(
          data.AttachmentData !== undefined ? data.AttachmentData : data.Attachments
        )
        if (serverList.length > 0) {
          this.selectedWeaponAttachments = serverList
          if (this.selectedWeaponSlot) this._writeAttToInventory(this.selectedWeaponSlot, serverList)
        }
      } catch (_) {
        // keep local
      }
    },

    async removeAttachment(attachment) {
      if (!this.selectedWeapon || this.attachmentsBusy) return

      const keyOf = (a) => a?.__k || this._attKey(a)
      const toRemoveKey = keyOf(attachment)
      if (!toRemoveKey) return

      // Optimistic UI: filter to a NEW array (no in-place splice)
      const optimistic = (this.selectedWeaponAttachments || []).filter(
        (a) => keyOf(a) !== toRemoveKey
      )
      this.selectedWeaponAttachments = optimistic

      this.attachmentsBusy = true
      try {
        const res = await axios.post('https://qb-inventory/RemoveAttachment', {
          AttachmentData: attachment,
          WeaponData: this.selectedWeapon
        })
        const data = res?.data || {}

        // If server returns updated WeaponData, replace the slot item (reactivity)
        if (data.WeaponData && this.selectedWeaponSlot) {
          const updated = { ...data.WeaponData, slot: this.selectedWeaponSlot }
          this.playerInventory[this.selectedWeaponSlot] = updated
          this.selectedWeapon = updated
          this.contextMenuItem = updated
        }

        // First attempt: read list from server
        const readOnce = async () => {
          try {
            const r = await axios.post('https://qb-inventory/GetWeaponData', {
              weapon: this.selectedWeapon.name,
              ItemData: this.selectedWeapon
            })
            const d = r?.data || {}
            const lst = this._normAtt(
              d.AttachmentData !== undefined ? d.AttachmentData : d.Attachments
            )
            return lst
          } catch {
            return null
          }
        }

        let finalList = await readOnce()

        // If empty or null, retry once after 150ms (server update window)
        if (!finalList || finalList.length === 0) {
          await new Promise((res) => setTimeout(res, 150))
          finalList = await readOnce()
        }

        // If still empty, keep optimistic list (do not wipe UI)
        if (!finalList || finalList.length === 0) {
          finalList = optimistic
        }

        // Update UI and inventory
        this.selectedWeaponAttachments = finalList
        if (this.selectedWeaponSlot) this._writeAttToInventory(this.selectedWeaponSlot, finalList)

        // Add returned attachment item to a free slot (if any)
        if (data.itemInfo) {
          const next = this.findNextAvailableSlot?.(this.playerInventory)
          if (next !== null && next !== undefined) {
            const give = { ...data.itemInfo, amount: data.itemInfo.amount || 1, slot: next }
            this.playerInventory[next] = give
          }
        }
      } catch (_) {
        // If remove failed, revert UI (normalize to ensure keys)
        const reverted = (this.selectedWeaponAttachments || []).concat(attachment)
        this.selectedWeaponAttachments = this._normAtt(reverted)
      } finally {
        this.attachmentsBusy = false
      }
    },

    closeWeaponAttachments() {
      this.showWeaponAttachments = false
      this.attachmentsBusy = false
      this.selectedWeapon = null
      this.selectedWeaponSlot = null
      this.selectedWeaponAttachments = []
    },

    // ---------- Tooltip / formatting ----------
    generateTooltipContent(item) {
      if (!item) return ''
      let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`
      const description =
        item.info && item.info.description
          ? item.info.description.replace(/\n/g, '<br>')
          : item.description
            ? item.description.replace(/\n/g, '<br>')
            : 'No description available.'

      if (item.info && Object.keys(item.info).length > 0) {
        for (const [key, value] of Object.entries(item.info)) {
          if (key !== 'description') {
            let valueStr = value
            if (key === 'attachments') {
              valueStr = Object.keys(value).length > 0 ? 'true' : 'false'
            }
            content += `<div class="tooltip-info"><span class="tooltip-info-key">${this.formatKey(
              key
            )}:</span> ${valueStr}</div>`
          }
        }
      }

      content += `<div class="tooltip-description">${description}</div>`
      content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${
        item.weight !== undefined && item.weight !== null
          ? (item.weight / 1000).toFixed(1)
          : 'N/A'
      }kg</div>`

      content += `</div>`
      return content
    },
    formatKey(key) {
      return key.replace(/_/g, ' ').charAt(0).toUpperCase() + key.slice(1)
    },

    // ---------- Server sync ----------
    postInventoryData(
      fromInventory,
      toInventory,
      fromSlot,
      toSlot,
      fromAmount,
      toAmount
    ) {
      let fromInventoryName =
        fromInventory === 'other' ? this.otherInventoryName : fromInventory
      let toInventoryName =
        toInventory === 'other' ? this.otherInventoryName : toInventory

      axios
        .post('https://qb-inventory/SetInventoryData', {
          fromInventory: fromInventoryName,
          toInventory: toInventoryName,
          fromSlot,
          toSlot,
          fromAmount,
          toAmount
        })
        .then(() => {
          this.clearDragData()
        })
        .catch((error) => {
          console.error('Error posting inventory data:', error)
        })
    }
  },
  mounted() {
    window.addEventListener('keydown', (event) => {
      const key = event.key
      if (key === 'Escape') {
        // 1) close attachments drawer first
        if (this.showWeaponAttachments) {
          event.preventDefault()
          this.closeWeaponAttachments()
          return
        }
        // 2) close context menu if open
        if (this.showContextMenu) {
          event.preventDefault()
          this.showContextMenu = false
          this.activeSubmenu = null
          return
        }
        // 3) close inventory
        if (this.isInventoryOpen) {
          event.preventDefault()
          this.closeInventory()
        }
      } else if (key === 'Tab') {
        event.preventDefault()
      }
    })

    window.addEventListener('message', (event) => {
      switch (event.data.action) {
        case 'open':
          this.openInventory(event.data)
          break
        case 'close':
          this.closeInventory()
          break
        case 'update':
          this.updateInventory(event.data)
          break
        case 'toggleHotbar':
          this.toggleHotbar(event.data)
          break
        case 'itemBox':
          this.showItemNotification(event.data)
          break
        case 'requiredItem':
          this.showRequiredItem(event.data)
          break
        default:
          console.warn(`Unexpected action: ${event.data.action}`)
      }
    })
  },

  beforeUnmount() {
    window.removeEventListener('mousemove', () => {})
    window.removeEventListener('keydown', () => {})
    window.removeEventListener('message', () => {})
  }
})

InventoryContainer.use(FloatingVue)
InventoryContainer.mount('#app')
