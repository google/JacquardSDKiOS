// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit

class JacquardSectionHeader: UIView {

  var title = "" {
    didSet {
      header?.text = title
    }
  }

  private var header: UILabel?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor.tableViewSectionBackground
    header = UILabel(frame: CGRect(x: 24.0, y: 11.0, width: 250.0, height: 18.0))
    header?.textColor = UIColor.tableViewSectionTitle
    header?.font = UIFont.system12Medium
    if let header = header {
      addSubview(header)
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
