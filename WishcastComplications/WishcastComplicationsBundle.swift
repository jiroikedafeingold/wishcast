//
//  WishcastComplicationsBundle.swift
//  WishcastComplications
//
//  Created by Jiro on 10/27/26.
//

import WidgetKit
import SwiftUI

@main
struct WishcastComplicationsBundle: WidgetBundle {
    var body: some Widget {
        WishcastComplications()
        WishcastWeekWidget()
    }
}
