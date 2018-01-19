/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Storage
import CoreData
import Shared

private let log = Logger.browserLogger

class FavoritesDataSource: NSObject, UICollectionViewDataSource {
    var frc: NSFetchedResultsController<NSFetchRequestResult>?
    weak var collectionView: UICollectionView?

    var isEditing: Bool = false {
        didSet {
            if isEditing != oldValue {
                // We need to post notification here to inform all cells to show the edit button.
                // collectionView.reloadData() can't be used, it stops InteractiveMovementForItem,
                // requiring user to long press again if he wants to reorder a tile.
                let name = isEditing ? NotificationThumbnailEditOn : NotificationThumbnailEditOff
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
    }

    override init() {
        super.init()

        frc = FavoritesHelper.frc()
        frc?.delegate = self

        do {
            try frc?.performFetch()
        } catch {
            log.error("Favorites fetch error")
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return frc?.fetchedObjects?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Thumbnail", for: indexPath) as! ThumbnailCell
        return configureCell(cell: cell, at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Using the same reorder logic as in BookmarksPanel
        Bookmark.reorderBookmarks(frc: frc, sourceIndexPath: sourceIndexPath, destinationIndexPath: destinationIndexPath)
    }

    fileprivate func configureCell(cell: ThumbnailCell, at indexPath: IndexPath) -> UICollectionViewCell {
        guard let fav = frc?.object(at: indexPath) as? Bookmark else { return UICollectionViewCell() }

        cell.textLabel.text = fav.displayTitle ?? fav.url
        cell.accessibilityLabel = cell.textLabel.text

        cell.toggleRemoveButton(isEditing)

        guard let collection = collectionView, let urlString = fav.url, let url = URL(string: urlString) else {
            log.error("configureCell url is nil")
            return UICollectionViewCell()
        }
        
        let ftd = FavoritesTileDecorator(url: url, cell: cell, indexPath: indexPath)
        ftd.collection = collectionView
        ftd.decorateTile()

        cell.updateLayoutForCollectionViewSize(collection.bounds.size, traitCollection: collection.traitCollection, forSuggestedSite: false)
        return cell
    }
}

extension FavoritesDataSource: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            if let indexPath = indexPath {
                collectionView?.insertItems(at: [indexPath])
            }
            break
        case .delete:
            if let indexPath = indexPath {
                collectionView?.deleteItems(at: [indexPath])
            }
            break
        case .update:
            if let indexPath = indexPath, let cell = collectionView?.cellForItem(at: indexPath) as? ThumbnailCell {
                _ = configureCell(cell: cell, at: indexPath)
            }
            if let newIndexPath = newIndexPath, let cell = collectionView?.cellForItem(at: newIndexPath) as? ThumbnailCell {
                _ = configureCell(cell: cell, at: newIndexPath)
            }
            break
        case .move:
            break
        }
    }
}
